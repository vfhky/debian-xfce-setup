# 手工安装软件清单（重装参考）

> 记录本机（Debian 13 trixie + XFCE）在基础系统之外**手工安装**的软件，按安装方式分类，附安装路径与安装包来源，供重装系统时按图索骥。
> 生成时间：2026-11-26。基础系统（XFCE 桌面、fcitx5 中文、中文字体等由 `task-xfce-desktop` / `task-chinese-s` 装好，不在此列）。

## A. 第三方 apt 仓库（先加仓库/密钥，再 apt 安装）

| 软件 | 仓库 | 安装命令 |
|---|---|---|
| Google Chrome | `/etc/apt/sources.list.d/google-chrome.sources` | `apt install google-chrome-stable` |
| Tailscale | `/etc/apt/sources.list.d/tailscale.list` | `apt install tailscale` |

## B. 官方 Debian 源直接 apt 安装

```bash
apt install git gh curl wget vim ripgrep \
            git-gui gitk git-cola \
            rabbitvcs-thunar rabbitvcs-cli \
            keepassxc \
            xfce4-docklike-plugin \
            bluetooth bluez blueman libspa-0.2-bluetooth
```

## C. 本地 .deb 包安装（重装前需先备好 .deb；多数装入 /opt）

| 软件 | 当前版本 | 安装路径 | .deb 来源 |
|---|---|---|---|
| NyaTerm | 2.0.8 | /opt/nyaterm | ~/桌面/NyaTerm_2.0.8_linux_x64.deb |
| Obsidian | 1.15.0 | /opt/Obsidian | ~/桌面/obsidian_1.15.0_amd64.deb |
| Orca (orca-ide) | 1.4.274 | /opt/Orca | orca-updater 自动更新；初始包 orca-ide_*.deb |
| Sublime Text | 4215 | /opt/sublime_text | ~/桌面/sublime-text_build-4215_amd64.deb |
| RustDesk | 1.5.3 | (系统) | ~/桌面/rustdesk-1.5.3-x86_64.deb |
| WeChat 微信 | 4.1.13.26 | /opt/wechat | Ventoy/soft/WeChatLinux_x86_64.deb |
| QQ (linuxqq) | 3.2.34 | /opt/QQ | Ventoy/soft/QQ_3.2.34_*_amd64.deb |
| Clash Verge | 2.5.10 | (系统) | Ventoy/soft/Clash.Verge_2.5.10_amd64.deb |
| WindInput 问剑输入法 | 0.125.0 | (系统) | Ventoy/soft/WindInput-0.125.0-linux-amd64.deb |
| MisterDownloadManager | 0.5.2 | /usr/bin/misterdownloadmanager | ~/桌面/MisterDownloadManager-0.5.2-linux-x86_64.deb |
| Git-Tree | 3.0.6 | (系统) | ~/桌面/Git-Tree_3.0.6_amd64.deb |
| Google Chrome | 155 | /opt/google | 见 A（有 apt 仓库，优先用仓库） |

安装方式：`sudo apt install ./xxx.deb`（apt 会自动解决依赖）。

**安装包在桌面、当前未安装（可选）**：`NoteGen_0.39.2`、`OpenIDEA_0.1.49`、`DuGuanjia_Setup_Linux_amd64`。

## D. 独立/绿色安装（家目录，非 apt 管理）

| 软件 | 位置 | 说明 |
|---|---|---|
| Telegram | ~/.local/opt/Telegram | 配 telegram-updater 自更新 |
| uv / uvx (Python) | ~/.local/bin | Astral uv，官方安装脚本装 |
| Claude Code (claude) | ~/.local/bin | |
| magpie | ~/.local/bin | AI 网关 |

## E. 运行时 / SDK（由 sdkm 统一管理）

- **sdkm**：`~/.sdkm/sdkm`（多版本 SDK 管理器，自带二进制 + config.toml + store/links）
- **Node.js 26.13.0**：`~/.sdkm/store/node/26.13.0`
- **Go 1.27.3**：`~/.sdkm/store/go/1.27.3`（GOPATH=~/go）
- 未装 rustup / conda / pyenv。

## F. GPU 驱动

- **nvidia-driver 550.163.01**（闭源，CUDA/NVENC）→ 直接用本仓库 `init-nvidia-driver.sh` 一键装。

## G. 本机未安装 / 未使用

- **Docker**：本机未装（dockerHub 项目走 GitHub Actions 构建镜像，不在本机跑 docker）。
- flatpak / snap：均无。

## 重装建议顺序

1. 装系统（XFCE + 中文）→ 2. `init-nvidia-driver.sh`（GPU 驱动）→ 3. 加第三方源装 Chrome/Tailscale →
4. B 组 apt 常用包 → 5. sdkm 装 Node/Go → 6. uv / claude → 7. C 组本地 .deb 应用 →
8. 输入法（fcitx5 + WindInput）→ 9. 恢复数据与配置。

> ⚠️ C 组 .deb 多在 `~/桌面` 与 Ventoy U 盘 `/soft`，**重装前务必先备份到 U 盘/外置盘**（`/data`、`~` 非独立分区会被清空）。