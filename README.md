# debian-xfce-setup

Debian 13 (trixie) + XFCE 桌面重装后的一键初始化脚本集合（组件化架构）。

每个软件 = 一个可独立运行的组件；`init.sh` 负责发现 / 选择 / 隔离执行 / 汇总。增删软件不碰主脚本，可自由组合，单组件可单独排查。

## 结构

| 路径 | 作用 |
|---|---|
| `init.sh` | **编排器**：发现 `components/*.sh`，按序隔离执行，三态（✓/✗/⊘）汇总。 |
| `lib/common.sh` | 共享库：日志 / dry-run / 安装器（`install_deb` 本地优先、`gh_latest_deb`、apt 仓库助手）+ 组件契约 `component_main`。 |
| `components/NN-name.sh` | 每个软件一个组件（`NN-` 定序，`name` 即选择 id）。 |
| `profiles/*.conf` | 组件组合清单（`desktop` / `minimal`）。 |
| `init-nvidia-driver.sh` | 闭源 NVIDIA 驱动安装（由 `50-nvidia` 组件调用，也可单独跑）。 |
| `init-system.sh` | 向后兼容 shim，转发到 `init.sh`。 |

## 用法

```bash
sudo bash init.sh --list                     # 列出所有组件（id / 类型 / 说明）
sudo bash init.sh --dry-run                  # 预演全部（不联网、不改动）
sudo bash init.sh                            # 按文件名顺序跑全部
sudo bash init.sh chrome obsidian nvidia     # 只跑指定组件（自由组合，按给出顺序）
sudo bash init.sh --profile desktop          # 跑 profile 里列的组件
bash components/30-obsidian.sh --dry-run     # 单独跑/调试某个组件
```

失败语义：尽力而为跑完，单个组件失败只标 ✗、不中断其余；末尾汇总 `✓/✗/⊘`，只要有 ✗ 则 `init.sh` 退出非零（`--strict` 遇 ✗ 即停）。每组件日志在 `logs/<id>.log`。

## 组件来源类型

- `apt` / `apt_repo`：官方 Debian 源或第三方 apt 仓库（Chrome / Sublime / Tailscale，自包含加源 + update + 装）。
- `github`：自动取 GitHub 最新 `.deb`（Obsidian / RustDesk / Clash Verge，走 `github.com` 避开 api 限流）。
- `url`：官方直链；组件顶部 `URL="${XXX_URL:-}"` 填一次即自动下载，留空则 ⊘ 跳过（微信 / QQ / 问剑 / NyaTerm / Git-Tree 等内部/无稳定公开源，**不臆造 URL**）。
- `script`：自定义逻辑（nvidia 包装 / uv-claude / sdkm / 输入法 / Telegram 备份恢复）。

可选离线：把 `.deb` 放进 `PKG_DIR`（默认 `~/reinstall-pkgs`），`install_deb` 本地优先、不下载。

## 新增一个软件

在 `components/` 丢一个 `NN-<name>.sh`（照抄任一现有组件的 `ID/TYPE/ORDER/DESC` + `body()` + 守卫结构），`init.sh` 自动发现，无需改主脚本。

## init-nvidia-driver.sh 说明

**背景**：nouveau 在较新的 NVIDIA 显卡（如 Ada / RTX 40 系）上不稳定，X server 容易在 Mesa glamor 路径段错误，导致桌面崩溃、被踢回登录界面；且 nouveau 不支持 CUDA。闭源驱动同时解决稳定性与算力。

**脚本做的事**：检测 Secure Boot → 给 apt 源补 `contrib non-free`（自动备份，兼容两种格式）→ `apt-get update` → 装 `linux-headers-$(uname -r)` → 装 `nvidia-driver`（DKMS 编译）→ `update-initramfs` + 校验。

```bash
sudo bash init-nvidia-driver.sh --dry-run   # 预演
sudo bash init-nvidia-driver.sh             # 安装
sudo reboot                                 # 重启生效
```

重启后验证：`nvidia-smi` / `lsmod | grep -E '^nvidia|^nouveau'` / `lspci -nnk | grep -A3 -i 'vga\|3d'`。

**回退**（重启后进不了桌面）：`Ctrl+Alt+F3` → `sudo apt purge 'nvidia*' && sudo apt install --reinstall nvidia-driver`。

> 内核更新后若 X 崩溃复发，先查 `dkms status`，确认 `nvidia-current` 对当前内核为 `installed`。