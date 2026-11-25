# debian-xfce-setup

Debian 13 (trixie) + XFCE 桌面重装后的一键初始化脚本集合。

每台机器重装系统后，按顺序跑对应脚本即可快速恢复到可用状态。

## 脚本

| 脚本 | 作用 | 用法 |
|---|---|---|
| `init-system.sh` | **总入口**：按 `SOFTWARE.md` 一键初始化（第三方源 + 常用 apt 包 + 离线 .deb 应用 + uv/claude + 调 GPU 驱动）。幂等、支持 `--dry-run`。 | `sudo bash init-system.sh` |
| `init-nvidia-driver.sh` | 把显示驱动从开源 `nouveau` 切换到闭源 `nvidia-driver`，解锁 CUDA / NVENC / NVDEC。幂等、自动备份 apt 源。（由 init-system.sh 自动调用，也可单独跑） | `sudo bash init-nvidia-driver.sh` |

`SOFTWARE.md`：手工安装软件清单（按安装方式分类，附路径与安装包来源）。

### init-system.sh 的离线包目录

C 组应用（NyaTerm / Obsidian / Orca / Sublime / RustDesk / 微信 / QQ / Clash / WindInput 等）以本地 `.deb` 安装。重装前把这些 `.deb` 备份到一个目录（默认 `~/reinstall-pkgs`，可用 `PKG_DIR=/路径` 覆盖），脚本会自动 `apt install` 它们；缺目录时只跳过该组、不影响其余步骤。

```bash
sudo bash init-system.sh --dry-run     # 先预览将执行的命令
sudo bash init-system.sh               # 正式执行
```

## init-nvidia-driver.sh 说明

**背景**：nouveau 在较新的 NVIDIA 显卡（如 Ada / RTX 40 系）上不稳定，X server 容易在 Mesa glamor 路径段错误，导致整个桌面崩溃、被踢回登录界面；且 nouveau 不支持 CUDA。闭源驱动可同时解决稳定性与算力问题。

**脚本做的事**：
1. 检测 Secure Boot（开启则提示 MOK 注册）
2. 给 apt 源补 `contrib non-free`（自动备份，兼容 `sources.list` 与 deb822 两种格式）
3. `apt-get update`
4. 安装当前内核头 `linux-headers-$(uname -r)`（DKMS 编译必需）
5. 安装 `nvidia-driver`（DKMS 自动编译内核模块）
6. `update-initramfs` + 安装后校验

**用法**：
```bash
# 先预演，确认不会拆桌面（只模拟，不装）
sudo bash init-nvidia-driver.sh --dry-run

# 正式安装
sudo bash init-nvidia-driver.sh

# 重启生效
sudo reboot
```

**重启后验证**：
```bash
nvidia-smi                            # 显卡型号 + Driver 版本 + CUDA 版本
lsmod | grep -E '^nvidia|^nouveau'    # 有 nvidia、无 nouveau
lspci -nnk | grep -A3 -i 'vga\|3d'    # N 卡 "Kernel driver in use: nvidia"
```

**回退**（若重启后进不了桌面）：`Ctrl+Alt+F3` →
```bash
sudo apt purge 'nvidia*' && sudo apt install --reinstall nvidia-driver
```

> 提示：内核更新后若 X 崩溃复发，先查 `dkms status`，确认 `nvidia-current` 对当前内核为 `installed`（DKMS 重编失败会静默回退到 nouveau）。