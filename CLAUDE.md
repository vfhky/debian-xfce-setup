# CLAUDE.md — 本仓库协作与 Git 提交规范

> 本文件是给在本仓库（`debian-xfce-setup`）工作的开发者 / Agent 的**硬性约定**。
> 前提：本仓库是**公开仓库**，一切以「可公开、可复现、不含隐私」为准。

## 一、提交信息格式（Conventional Commits）

- 格式：`<type>(<scope>): <subject>`
  - **type**：`feat` | `fix` | `refactor` | `perf` | `docs` | `test` | `chore` | `build` | `ci` | `revert`
  - **scope**：受影响的组件 / 区域，如 `components` `lib` `init` `scripts` `profiles` `tests` `docs`，或具体组件 id（如 `components(obsidian)`）
  - **subject**：祈使句、简洁一行；正文（可选）说明「改了什么 + 为什么」，可用中文。
- 参考本仓库既有提交：
  - `feat(components): obsidian/rustdesk/clash-verge via GitHub latest`
  - `fix: profile last-entry drop (no trailing newline)`
  - `chore: ignore IDE/editor dirs and temp files in .gitignore`

## 二、原子提交

- 一个提交只做**一件逻辑上的事**；不要把「重构 + 加功能 + 改文档」塞进一个提交。
- 配对的改动（代码 + 对应测试 + 文档）放在**同一个**提交里。

## 三、提交前测试必须通过（硬性）

- 提交前跑全部测试并确保全绿：
  ```bash
  for t in tests/t0*.sh; do bash "$t" || exit 1; done
  ```
- 新增 / 修改组件遵循 TDD：**先写会失败的测试，再写实现**。

## 四、绝不提交隐私 / 密钥（硬性，本仓库公开）

- **禁止**提交：SSH / GPG 私钥、各类 token、密码、订阅链接，以及**个人 tailnet 域名、Tailscale IP、内网地址、个人绝对路径**等任何能定位到本人的信息。
- 需要个人值的地方：用**占位符 / 环境变量 / 命令行参数**注入，默认值留空或写通用占位（如 `<tailnet-domain>`、`<tailnet-ip>`）；真实值只存在本机私有位置，**不进仓库**。
- 反面教材：曾把含个人 tailnet 域名 / IP 的修复脚本直接提交并 push 到公开 `main`——此类脚本必须**先参数化、去掉个人默认值**再入库。
- 提交前自检：`git diff --cached` 里不得出现真实域名 / IP / 密钥。

## 五、不要提交 IDE / 编辑器状态

- `.openidea/` `.idea/` `.vscode/` `.cursor/` 等已在 `.gitignore`；**不要** `git add -f` 强行加入。
- 运行产物 `logs/`、`.superpowers/` 同理不入库。

## 六、提交署名

- 每个提交信息结尾追加一行：
  ```
  Co-Authored-By: Claude Code <noreply@anthropic.com>
  ```

## 七、分支与对外操作

- `main` 始终保持**测试通过、可复现**。
- **推送 / 合并 / 改写历史（force-push）/ 删除远端**等对外或不可逆操作，**先与业主确认**再做。
- 开源 `.deb` 一律走 GitHub 最新 release（见 `SOFTWARE.md` 与各组件）；拿不到官方 GitHub 包时如实说明，不编造 URL。