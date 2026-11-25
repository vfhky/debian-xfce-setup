# 组件化架构设计（debian-xfce-setup）

- 日期：2026-11-26
- 状态：设计待确认
- 适用仓库：`/data/github/debian-xfce-setup`

## 1. 意图与背景（为什么）

当前 `init-system.sh`（162 行）把三件事揉在一起：**配置表**（`GH_DEB` / `DEB_URL`）、**工具函数**（`install_deb` / `gh_latest_deb`）、**8 步内联流程**。增删一个软件要改主脚本，排查某个软件要在整段流程里找，无法单独跑、无法按需组合。

业主的三个核心诉求（原话）：
1. **以后增删软件不碰主脚本**（开闭原则）。
2. **可以随意组装各个软件**（按需挑装 / 排序）。
3. **方便排查问题**（单组件可独立运行、调试、隔离失败）。

## 2. 目标 / 非目标 / 反目标

**目标**
- 每个软件 = 一个可独立运行的组件脚本；公共逻辑收敛到 `lib/common.sh`。
- 编排器 `init.sh` 只做「发现 → 选择 → 按序隔离执行 → 汇总」，不含任何 app 逻辑。
- 支持：全装 / 挑装（命令行或 profile）/ 单组件独立跑 / `--dry-run` / 失败隔离 + 红绿汇总 / 每组件独立日志。
- 保持幂等；保持 `sudo bash init.sh` 开箱即用。

**非目标**
- 不做通用包管理器，不做数据/配置恢复（仍手工）。
- 不替代 `init-nvidia-driver.sh`（由 `50-nvidia` 组件包装调用）。
- 不引入声明式迷你语言（那是被否掉的方案 B/C）。
- 不自动下载内部/无公开源应用（不臆造 URL）。

**反目标（出现即算失败）**
- 编排器里重新长出 app 逻辑（单体化复辟）。
- 组件不能脱离编排器单独跑（毁掉"排查"）。
- 某个 app 失败导致整批中断。
- 隐式全局状态让排查变难。

## 3. 约束

- 纯 bash；Debian 13 trixie；需 root（`sudo`）运行。
- 幂等；支持 `--dry-run`；不写入任何密码/密钥；不臆造下载 URL。
- 本机不装/不用 docker（沿用既有约定，脚本不涉及 docker）。
- 向后兼容：老用法尽量保留（见 §7）。

## 4. 方案选型（已定 A）

- **A（选中）可运行脚本组件 + 共享库 + 编排器**：最贴合"每个软件一个脚本""方便排查"；`common.sh` 把标准 app 压到几行，通用化收益基本拿满，且无需维护额外 schema。
- **B 纯声明式（描述文件 + 引擎）**：简单 app 一行搞定，但 sdkm / uv-claude / 输入法 / 多步安装塞不进声明式，最后仍要 `type=script` 逃生口，等于回到脚本，还多维护一套 schema、排查多一层间接。否决。
- **C 混合（声明式 + 脚本逃生口）**：本质是 A 再加声明层，复杂度更高。否决。

## 5. 架构与契约（A 的具体设计）

### 5.1 目录结构
```
debian-xfce-setup/
├── init.sh                 # 编排器：选择 + 按序隔离执行 + 汇总（无 app 逻辑）
├── lib/common.sh           # 共享库：日志/隔离/dry-run + 各类安装器
├── components/             # 每个软件一个，NN- 前缀定序，NN-name 的 name 即选择 id
│   ├── 00-sourcelist.sh    # 启用 contrib non-free（script）
│   ├── 10-apt-base.sh      # B 组常用 apt 包（apt）
│   ├── 20-chrome.sh        # apt 仓库（apt_repo）
│   ├── 21-sublime.sh       # apt 仓库（apt_repo）
│   ├── 22-tailscale.sh     # apt 仓库（apt_repo）
│   ├── 30-obsidian.sh      # GitHub 最新（github）
│   ├── 31-rustdesk.sh      # GitHub 最新（github）
│   ├── 32-clash-verge.sh   # GitHub 最新（github）
│   ├── 40-wechat.sh        # 官方直链（url，URL 留空则跳过）
│   ├── 41-qq.sh            # url
│   ├── 42-windinput.sh     # url（问剑输入法）
│   ├── 43-nyaterm.sh       # url（本地优先）
│   ├── 44-git-tree.sh      # url
│   ├── 50-nvidia.sh        # 包装 init-nvidia-driver.sh（script）
│   ├── 60-user-tools.sh    # uv / claude（script，用户级）
│   ├── 61-sdkm.sh          # sdkm 装 Node/Go（script，需备份恢复）
│   ├── 70-input-method.sh  # fcitx5 + 输入法启用校验（script）
│   └── 90-telegram.sh      # 从备份恢复 ~/.local/opt/Telegram（script）
├── profiles/
│   ├── desktop.conf        # 组件 id 列表（自由组合）
│   └── minimal.conf
└── logs/                   # 运行时生成：每组件一份 <id>.log
```

### 5.2 组件契约（每个组件都长一个样）
```bash
#!/usr/bin/env bash
set -uo pipefail
ID=obsidian; TYPE=github; ORDER=30; DESC="Obsidian（GitHub 最新 .deb）"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body() {
  gh_latest_deb "obsidianmd/obsidian-releases" 'obsidian.*amd64\.deb'
}
# 仅被直接执行时才跑；被 source（--list 读元数据）时不执行 body
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi
```
- 顶部 4 个变量 `ID/TYPE/ORDER/DESC` 是**标准元数据**（供汇总/选择/排序）。
- `TYPE` **仅信息性**（供 `--list`/汇总展示）；编排器**不按 TYPE 分派**（否则又把 app 逻辑长回编排器，违反 §2）。
- `body()` 是组件唯一业务；用 `common.sh` 的安装器写成几行。
- `component_main`（库提供）：打印头、按全局 `DRY_RUN` 直通、把输出 tee 到 `logs/<ID>.log`、调 `body`、据 `body` 退出码打 ✓/✗/⊘ 并以对应码退出。
- **可独立运行**：`bash components/30-obsidian.sh [--dry-run]` 直接跑/调试（`bash -x` 亦可）。
- **`--list` 读元数据**：编排器 `source` 各组件读顶部 `ID/TYPE/DESC`——底部 `BASH_SOURCE` 守卫保证 source 时不执行 `body`（或组件支持 `--describe` 打印元数据即退）。

### 5.3 lib/common.sh 提供的安装器（迁移现有逻辑）
- 基础：`log/warn/die/run/as_user`、`have <pkg>`（dpkg 探测）、root 与 `--dry-run` 处理、路径解析。
- **失败语义**：所有安装器（`install_deb`/`gh_latest_deb`/`apt_install`/`add_apt_repo_*`）**失败一律返回非零**（不再 warn-and-continue），由 `body` 透传、`component_main` 据此判 ✓/✗/⊘。这样汇总才有意义。
- `install_deb <out> <url>`：下载并 `apt install`；**local-first**：若 `PKG_DIR` 有匹配 `.deb` 则用本地不下载。
- `gh_latest_deb <owner/repo> <regex>`：走 `github.com` 的 `releases/latest` + `expanded_assets`（**避开 api 限流**，已实测）；同样 local-first。
- `apt_install <pkgs...>`。
- apt 仓库两个泛化助手（**自包含**：各自加密钥/源 + `apt-get update` + 装自己的包）：
  - `add_apt_repo_dearmor <name> <keyring-url> <list-line>`——适用 Chrome/Sublime（下载 key 去armor + 写 list）。
  - `add_apt_repo_prebuilt <name> <keyring-url> <list-url>`——适用 Tailscale（下载现成 `noarmor.gpg` + 现成 `.list`）。
- `component_main`：组件统一入口（见 §5.2、§5.6）。

### 5.4 编排器 init.sh 行为
- 发现：扫描 `components/*.sh`；`source` 读顶部元数据（守卫保证不执行 body）。
- 排序键（唯一定义，避免与 `ORDER` 冲突）：
  - **无选择**（无参数）→ 跑**全部**，按文件名 `NN-` 升序。
  - **显式选择**（argv 的 id 列表，或 `--profile` 里列的 id）→ **按选择顺序**执行（因此可自由重排）。
  - `ORDER` 变量 = 由 `NN-` 派生的展示用元数据，不单独load-bearing。
- 默认行为：**bare `sudo bash init.sh` = 跑全部组件**（开箱即用）；profile 为可选（`--profile desktop`）。
- 选择/组合：`init.sh obsidian rustdesk`、`init.sh --profile minimal`、`--list`（列 id/type/desc）、`--dry-run`（全局直通，导出 `DRY_RUN` 并给子进程追加 `--dry-run`）、`--strict`（遇 ✗ 即停）。
- 隔离：每个组件独立 `bash components/NN-id.sh` 子进程跑，捕获退出码；默认**失败不中断**（`--strict` 改为中断）。
- 汇总：末尾打印三态表（id / ✓✗⊘ / 耗时）+ 总计；指向 `logs/<id>.log`。
- `init.sh` 退出码：见 §5.6（取决于业主对失败语义的选择，**待确认**）。

### 5.5 url 型组件的 URL 归属与本地优先
- 取消中央 `DEB_URL` 表；每个 url 组件自带 `URL="${WECHAT_URL:-}"`（可环境变量覆盖），**留空则该组件判为 ⊘ 跳过**并提示从备份恢复。URL 与组件同处，符合"增删不碰主脚本"。
- **PKG_DIR 本地优先**下沉到 `install_deb`/`gh_latest_deb`（见 §5.3），对所有类型生效。
- 原 step 4d「安装 PKG_DIR 里所有剩余 .deb」是全局清扫、无单 app 归属：**取消**该全局行为（改为各组件 local-first 命中即用）；如需保留，另加可选组件 `99-local-sweep`（默认不启用）。

### 5.6 三态与退出码（✓ / ✗ / ⊘）
- **⊘ 跳过**（exit 0）：url 为空、目标已存在、需从备份恢复等"无需/无法安装但非错误"。
- **✓ 成功**（exit 0）；**✗ 失败**（非零）：安装器报错。
- `component_main` 据 `body` 退出码映射三态；`init.sh` 汇总据此着色。
- **`init.sh` 整体退出码（已定）**：尽力而为——跑完全部组件，只要有任何 ✗ 则退出非零；`--strict` 时遇 ✗ 即停并退出非零。

## 6. 现有 8 步 → 组件映射
| 现步骤 | 组件 |
|---|---|
| 1 启用 contrib non-free | `00-sourcelist` |
| 2 Chrome/Sublime/Tailscale 源 | `20-chrome` / `21-sublime` / `22-tailscale` |
| 3 B 组 apt + 三件 | `10-apt-base`（**仅 B 组**）；Chrome/Sublime/Tailscale 由 `20/21/22` **各自自包含**（加源 + update + 装自己） |
| 4 下载安装应用 | `30/31/32`（github）+ `40-44`（url） |
| 5 uv/claude | `60-user-tools` |
| 6 sdkm/Telegram/magpie | `61-sdkm` / `90-telegram`（magpie 并入或单列） |
| 7 GPU 驱动 | `50-nvidia` |
| 8 汇总 | 由 `init.sh` 承担 |

## 7. 兼容性
- 新增 `init.sh` 为新入口；`init-system.sh` 保留为 2 行 shim（`exec bash "$(dirname "$0")/init.sh" "$@"`）或直接替换并更新 README（**待业主定**，见 §8）。
- `init-nvidia-driver.sh` 不动，被 `50-nvidia` 调用。

## 8. 决策记录 / 留给执行者

**已定（业主确认）**
- **失败语义与 `init.sh` 退出码 = 尽力而为 + 有错非零退出**：单个组件失败只标 ✗、不中断其余；汇总如实显示 ✓/✗/⊘；全部跑完后只要有任何 ✗，`init.sh` 退出非零（便于自动化感知）；`--strict` 时遇 ✗ 即停。

**留给执行者（builder 可自定）**
- 组件清单与顺序（§5.1 为建议，可增删，如 NoteGen/OpenIDEA/MDM 可选组件）。
- profile 具体内容（desktop / minimal 各含哪些 id）。
- `init-system.sh` 保留 shim 还是直接替换。
- 日志目录位置（建议仓库内 `logs/`）。
- magpie 单列组件还是并入 `90`。
- `--dry-run`/`--strict` 传递：编排器导出 `DRY_RUN`/`STRICT` 并给子进程追加 `--dry-run`；`50-nvidia` 把 `--dry-run` 转发给 `init-nvidia-driver.sh`。

## 9. 验收
- `bash -n` 全绿；`sudo bash init.sh --dry-run` 与 `--list` 正常。
- 单组件 `bash components/30-obsidian.sh --dry-run` 可独立跑。
- 模拟某组件失败，其余照跑且汇总标红。
- `gh_latest_deb` 三仓解析到真实最新 .deb（已验证）。