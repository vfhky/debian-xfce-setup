# 组件化架构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把单体 `init-system.sh` 重构为「每软件一个可独立运行组件 + 共享库 + 编排器」的架构，支持增删不碰主脚本、自由组合、单组件排查。

**Architecture:** `lib/common.sh` 提供日志/隔离/dry-run 与各类安装器及 `component_main` 契约；`components/NN-name.sh` 每个声明 `ID/TYPE/ORDER/DESC` + `body()`，底部 `BASH_SOURCE` 守卫使其可 source（供 `--list`）也可直接执行；`init.sh` 只发现/选择/隔离执行/三态汇总。

**Tech Stack:** bash 4+（关联数组、`BASH_SOURCE`）、apt、curl/wget、GitHub `releases/latest`+`expanded_assets`（避开 api 限流）。无第三方测试框架（保持零依赖，便于新机引导）。

**Spec:** `docs/superpowers/specs/2026-11-26-component-architecture-design.md`

## Global Constraints

- 纯 bash；`set -uo pipefail`（**不用 `-e`**）；需 root 运行（`sudo`）。
- 幂等；全程支持 `--dry-run`（不下载/不安装/无网络副作用）；不写入任何密码/密钥；不臆造下载 URL。
- 安装器失败**一律返回非零**；组件三态 ✓ok / ✗fail / ⊘skip；`init.sh` 尽力而为跑完，有 ✗ 则退出非零，`--strict` 遇 ✗ 即停。
- 排序：无选择按文件名 `NN-` 升序；显式选择（argv/profile）按给出顺序。`ORDER` 仅展示。
- 组件 id = 文件名去掉 `NN-` 前缀与 `.sh`。
- 本机不涉及 docker。

## Review Focus

- **组件在打印结果行前崩溃**（语法错/source 失败）→ `init.sh` 必须记 ✗ 并继续，不得静默丢弃。（Task 3 测）
- **`--dry-run` 零副作用**：不联网、不装；`50-nvidia` 必须把 `--dry-run` 透传给 `init-nvidia-driver.sh`。（Task 3、7 测）
- **url 组件 URL 为空/空白** → ⊘skip，不得对空串 wget。（Task 6 测）
- **PKG_DIR 本地优先**：命中本地 `.deb` 则不联网；`PKG_DIR` 不存在时不报错。（Task 2 测）
- **选择未知 id（拼错）** → 明确报错并非零退出，不得静默 no-op。（Task 3 测）

---
### Task 1: `lib/common.sh` 基础与 `component_main` 契约

**Files:**
- Create: `lib/common.sh`
- Create: `.gitignore`（忽略 `logs/`）
- Test: `tests/t01-component-contract.sh`

**Interfaces:**
- Produces（供所有组件与 init.sh 使用）:
  - 全局: `DRY_RUN` `STRICT` `REAL_USER` `REAL_HOME` `PKG_DIR` `REPO_ROOT` `LOG_DIR` `COMPONENTS_DIR` `RESULT_STATE`
  - 日志: `log/warn/die/ok/fail/skip`；`skip <msg>` 置 `RESULT_STATE=skip` 并返回 0
  - 执行: `run <cmd...>`、`as_user <cmd...>`（dry-run 时只打印）
  - 探测: `have <pkg>`（dpkg -s）
  - 契约: `component_main`（读 `ID/TYPE/ORDER/DESC`；跑 `body`；据 body 退出码 + `RESULT_STATE` 定三态；打印 `__RESULT__|<id>|<ok|skip|fail>|<ms>`；ok/skip 退出 0，fail 退出 1）

- [ ] **Step 1: 写失败测试** `tests/t01-component-contract.sh`：source `lib/common.sh`，定义 `ID=t T= t ORDER=0 DESC=d` 与 `body(){ skip "no url"; }`，调用 `component_main`，断言输出含 `__RESULT__|t|skip|` 且退出码 0；再定义 `body(){ return 3; }` 断言得 `__RESULT__|t|fail|` 且退出码 1。
- [ ] **Step 2: 运行确认失败** `bash tests/t01-component-contract.sh` → FAIL（common.sh 不存在）。
- [ ] **Step 3: 实现 `lib/common.sh`**：路径用 `REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`；`DRY_RUN=${DRY_RUN:-0}`（并解析 `--dry-run`）、`STRICT=${STRICT:-0}`；`REAL_USER=${SUDO_USER:-$USER}`、`REAL_HOME` 由 getent、`PKG_DIR=${PKG_DIR:-$REAL_HOME/reinstall-pkgs}`、`LOG_DIR="$REPO_ROOT/logs"`、`COMPONENTS_DIR="$REPO_ROOT/components"`；`component_main` 用 `mkdir -p "$LOG_DIR"`、整体输出 `tee -a "$LOG_DIR/$ID.log"`、末尾打印结果行；`body` 直接调用（非子shell）以保留 `skip` 的状态，用 `local rc=$?` 捕获。
- [ ] **Step 4: 运行确认通过** `bash tests/t01-component-contract.sh` → PASS（两条断言）。
- [ ] **Step 5: 提交**
```bash
git add lib/common.sh .gitignore tests/t01-component-contract.sh
git commit -m "feat(lib): component contract + common.sh foundation"
```

### Task 2: `lib/common.sh` 安装器

**Files:**
- Modify: `lib/common.sh`（追加安装器）
- Test: `tests/t02-installers.sh`

**Interfaces:**
- Consumes: Task 1 的 `run/have/warn/DRY_RUN/PKG_DIR`。
- Produces:
  - `install_deb <out-name> <url>`：若 `$PKG_DIR/<out-name>`（或按 url basename）存在则本地 `apt install`；否则 `wget -q -O "$TMP/<out>" "<url>" && apt install -y`；dry-run 只打印；失败返回非零。
  - `gh_latest_deb <owner/repo> <regex>`：`releases/latest` 取 tag → `expanded_assets/<tag>` grep `.deb` → `install_deb`；无匹配返回非零并 warn 链接。
  - `apt_install <pkgs...>`；`add_apt_repo_dearmor <name> <keyring-url> <list-line>`；`add_apt_repo_prebuilt <name> <keyring-url> <list-url>`（各自 `apt-get update` 后由组件装包）。

- [ ] **Step 1: 写失败测试** `tests/t02-installers.sh`：① `DRY_RUN=1; install_deb x.deb https://example/x.deb` 退出 0 且输出含 `[dry-run]`；② 造 `PKG_DIR` 放一个假 `.deb`，`install_deb` 走本地分支（输出含本地路径、不出现 wget）；③ `gh_latest_deb nonexistent-owner-xyz/nope 'x\.deb'` 返回非零。
- [ ] **Step 2: 运行确认失败** `bash tests/t02-installers.sh` → FAIL。
- [ ] **Step 3: 实现安装器**（`gh_latest_deb` 复用已验证的 tag+expanded_assets 逻辑；用 `mktemp -d` + trap 清理）。
- [ ] **Step 4: 运行确认通过** `bash tests/t02-installers.sh` → PASS。（可选联网校验：`gh_latest_deb rustdesk/rustdesk 'rustdesk-.*x86_64\.deb'` 打印真实 .deb URL）
- [ ] **Step 5: 提交**
```bash
git add lib/common.sh tests/t02-installers.sh
git commit -m "feat(lib): installers (install_deb/gh_latest_deb/apt repos) with local-first"
```

### Task 3: 编排器 `init.sh`

**Files:**
- Create: `init.sh`
- Test: `tests/t03-orchestrator.sh`（用临时 `components/` 假组件，不碰真组件）

**Interfaces:**
- Consumes: `lib/common.sh` 的元数据变量与 `LOG_DIR`。
- Produces: CLI `init.sh [--dry-run] [--strict] [--list] [--profile <name>] [id...]`；发现 `components/*.sh`；`--list` 读元数据；隔离子进程执行；解析每个组件输出的 `__RESULT__|<id>|<state>|<ms>` 行做三态汇总；退出码=有 fail 则非零。

- [ ] **Step 1: 写失败测试** `tests/t03-orchestrator.sh`：建临时目录放 `components/00-a.sh`(ok)、`10-b.sh`(fail)、`20-c.sh`(skip) 三个假组件（source 真 common.sh），断言：① `--list` 列出 a/b/c；② 跑完汇总含三态且 `init.sh` 退出非零；③ 传未知 id `zzz` → 报错非零；④ 组件在结果行前 `exit 7`（模拟崩溃）→ 记 ✗ 不中断其余。
- [ ] **Step 2: 运行确认失败** `bash tests/t03-orchestrator.sh` → FAIL。
- [ ] **Step 3: 实现 `init.sh`**：root 校验；解析参数；`--list` 用 `source` 读 `ID/TYPE/ORDER/DESC`（守卫防执行）；选择集=argv 或 `--profile` 文件行（`#` 注释）或全部；未知 id 收集后 `die`；循环 `bash "$f" "$@"`（追加 `--dry-run`）`2>&1 | tee` 并 grep `__RESULT__|`；无结果行→fail；汇总对齐三态；末尾按 fail 数定退出码。
- [ ] **Step 4: 运行确认通过** `bash tests/t03-orchestrator.sh` → PASS（四项）。
- [ ] **Step 5: 提交**
```bash
git add init.sh tests/t03-orchestrator.sh
git commit -m "feat(init): orchestrator with selection/composition, isolation, 3-state summary"
```

### Task 4: 基础组件（sourcelist / apt-base / 三 apt 仓库）

**Files:**
- Create: `components/00-sourcelist.sh`、`components/10-apt-base.sh`、`components/20-chrome.sh`、`components/21-sublime.sh`、`components/22-tailscale.sh`
- Test: `tests/t04-basic-components.sh`

**Interfaces:**
- Consumes: Task 1/2 全部 helper。
- Produces: 5 个组件，各自 `ID/TYPE/ORDER/DESC`+`body()`+守卫；`20/21/22` 自包含（加源+`apt-get update`+装自己包，用 `have` 幂等）；`10-apt-base` 仅 B 组包（git gh curl wget vim ripgrep git-gui gitk git-cola rabbitvcs-thunar rabbitvcs-cli keepassxc xfce4-docklike-plugin bluetooth bluez blueman libspa-0.2-bluetooth）。

- [ ] **Step 1: 写失败测试** `tests/t04-basic-components.sh`：对每个组件 `bash -n`；`DRY_RUN=1 bash components/20-chrome.sh` 输出含 `[dry-run]` 与 chrome 源行、退出 0；`bash init.sh --list` 含这 5 个 id。
- [ ] **Step 2: 运行确认失败** `bash tests/t04-basic-components.sh` → FAIL。
- [ ] **Step 3: 实现 5 个组件**（`00-sourcelist` 迁移现 step1 的 contrib non-free 逻辑；apt 仓库密钥/源 URL 用现脚本中的官方地址）。
- [ ] **Step 4: 运行确认通过** → PASS。
- [ ] **Step 5: 提交**
```bash
git add components/00-sourcelist.sh components/10-apt-base.sh components/20-chrome.sh components/21-sublime.sh components/22-tailscale.sh tests/t04-basic-components.sh
git commit -m "feat(components): sourcelist, apt-base, chrome/sublime/tailscale repos"
```

### Task 5: GitHub 最新组件（obsidian / rustdesk / clash-verge）

**Files:**
- Create: `components/30-obsidian.sh`、`components/31-rustdesk.sh`、`components/32-clash-verge.sh`
- Test: `tests/t05-github-components.sh`

**Interfaces:**
- Consumes: `gh_latest_deb`（Task 2）、`have`（幂等）。
- Produces: 3 组件，`body` 一行调 `gh_latest_deb`：obsidian→`obsidianmd/obsidian-releases` / `obsidian.*amd64\.deb`；rustdesk→`rustdesk/rustdesk` / `rustdesk-.*x86_64\.deb`；clash→`clash-verge-rev/clash-verge-rev` / `clash.*verge.*amd64\.deb`。已 `have` 则 `skip`。

- [ ] **Step 1: 写失败测试** `tests/t05-github-components.sh`：三组件 `bash -n`；`DRY_RUN=1 bash components/30-obsidian.sh` 打印「取 GitHub 最新 …」且退出 0；`init.sh --list` 含三 id。
- [ ] **Step 2: 运行确认失败** → FAIL。
- [ ] **Step 3: 实现 3 组件。**
- [ ] **Step 4: 运行确认通过** → PASS。（可选联网：对三仓 `gh_latest_deb` 解析出真实 .deb URL）
- [ ] **Step 5: 提交**
```bash
git add components/30-obsidian.sh components/31-rustdesk.sh components/32-clash-verge.sh tests/t05-github-components.sh
git commit -m "feat(components): obsidian/rustdesk/clash-verge via GitHub latest"
```

### Task 6: 官方直链组件（wechat / qq / windinput / nyaterm / git-tree）

**Files:**
- Create: `components/40-wechat.sh`、`41-qq.sh`、`42-windinput.sh`、`43-nyaterm.sh`、`44-git-tree.sh`
- Test: `tests/t06-url-components.sh`

**Interfaces:**
- Consumes: `install_deb`、`have`。
- Produces: 5 组件，各带 `URL="${WECHAT_URL:-}"`（qq→`QQ_URL`、windinput→`WINDINPUT_URL`、nyaterm→`NYATERM_URL`、git-tree→`GIT_TREE_URL`）；`body`：`have` 命中→skip；`URL` 去空白后为空→`skip "未配置 URL，从备份恢复"`；否则 `install_deb "<id>.deb" "$URL"`。

- [ ] **Step 1: 写失败测试** `tests/t06-url-components.sh`：五组件 `bash -n`；`DRY_RUN=1 bash components/40-wechat.sh`（URL 空）输出含 `skip`/`⊘` 且退出 0、**不含** `wget`；`WECHAT_URL=https://e/x.deb DRY_RUN=1 bash components/40-wechat.sh` 打印 `[dry-run] … x.deb`。
- [ ] **Step 2: 运行确认失败** → FAIL。
- [ ] **Step 3: 实现 5 组件。**
- [ ] **Step 4: 运行确认通过** → PASS。
- [ ] **Step 5: 提交**
```bash
git add components/4*.sh tests/t06-url-components.sh
git commit -m "feat(components): direct-url apps (wechat/qq/windinput/nyaterm/git-tree), skip when unset"
```

### Task 7: 脚本型组件（nvidia / user-tools / sdkm / input-method / telegram）

**Files:**
- Create: `components/50-nvidia.sh`、`60-user-tools.sh`、`61-sdkm.sh`、`70-input-method.sh`、`90-telegram.sh`
- Test: `tests/t07-script-components.sh`

**Interfaces:**
- Consumes: `run/as_user/have/skip`、`REPO_ROOT`、`REAL_HOME`。
- Produces: 5 组件。`50-nvidia`：`bash "$REPO_ROOT/init-nvidia-driver.sh" --dry-run`（**透传 dry-run**）。`60-user-tools`：`as_user` 装 uv/claude（`command -v` 幂等）。`61-sdkm`：无 `~/.sdkm` → skip 提示恢复。`70-input-method`：校验 fcitx5。`90-telegram`：无 `~/.local/opt/Telegram` → skip 提示恢复。

- [ ] **Step 1: 写失败测试** `tests/t07-script-components.sh`：五组件 `bash -n`；`DRY_RUN=1 bash components/50-nvidia.sh` 输出含 `init-nvidia-driver.sh --dry-run`（证明透传）；`DRY_RUN=1 bash components/61-sdkm.sh`（假设无 ~/.sdkm）含 `skip`；`init.sh --list` 含五 id。
- [ ] **Step 2: 运行确认失败** → FAIL。
- [ ] **Step 3: 实现 5 组件。**
- [ ] **Step 4: 运行确认通过** → PASS。
- [ ] **Step 5: 提交**
```bash
git add components/5*.sh components/6*.sh components/7*.sh components/90-telegram.sh tests/t07-script-components.sh
git commit -m "feat(components): nvidia wrapper, user-tools, sdkm, input-method, telegram"
```

### Task 8: profiles + 兼容 shim + 文档 + 收尾验证

**Files:**
- Create: `profiles/desktop.conf`、`profiles/minimal.conf`
- Create: `init-system.sh`（shim → `exec bash "$HERE/init.sh" "$@"`，覆盖旧文件）
- Modify: `README.md`、`SOFTWARE.md`（描述新架构与用法）
- Test: `tests/t08-integration.sh`

**Interfaces:**
- Consumes: 全部组件 + `init.sh`。
- Produces: `profiles/desktop.conf`（列常用 id）、`minimal.conf`（核心子集）；`init-system.sh` 向后兼容。

- [ ] **Step 1: 写失败测试** `tests/t08-integration.sh`：`bash init.sh --list` 列出全部组件 id；`sudo bash init.sh --profile desktop --dry-run` 退出 0 且只跑 profile 内 id；`bash init-system.sh --dry-run` 与 `bash init.sh --dry-run` 行为一致；全仓 `for f in lib/common.sh init.sh components/*.sh; do bash -n "$f"; done` 全绿。
- [ ] **Step 2: 运行确认失败** → FAIL。
- [ ] **Step 3: 实现 profiles + shim + 更新 README/SOFTWARE。**
- [ ] **Step 4: 运行确认通过** → PASS（含全仓 `bash -n`）。
- [ ] **Step 5: 提交**
```bash
git add profiles/ init-system.sh README.md SOFTWARE.md tests/t08-integration.sh
git commit -m "feat: profiles, init-system compat shim, docs; integration tests green"
```

## 自检（写作者已核对）
- Spec 覆盖：§5.1→T4-7、§5.2→T1、§5.3→T2、§5.4→T3、§5.5→T6、§5.6→T1/T3、§6 映射→T4-7、§7 兼容→T8、§9 验收→T8。无遗漏。
- 类型/命名一致：`component_main`/`install_deb`/`gh_latest_deb`/`add_apt_repo_dearmor`/`add_apt_repo_prebuilt`/`__RESULT__` 全程同名。
- Review Focus 五项各有归属测试（T3/T7/T6/T2/T3）。