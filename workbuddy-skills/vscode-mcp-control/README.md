# vscode-mcp-control · 让 WorkBuddy 直接驱动你的 VS Code

一个 WorkBuddy skill：让 AI 助手直接操控你那台已经配好插件、编译器、调试器的 VS Code——**文件读写、编辑器、搜索、LSP、命令、集成终端、断点调试**，全部通过 VS Code 本身完成，而不是在 WorkBuddy 的空壳 Bash 里另配一套环境。

> 实测环境：VS Code 1.140.0 + Windows 11 + Python 3.13 + nabheet/vscode-ide-mcp v0.3.51。六大类功能逐项实测通过。

---

## 它能干什么（六大类，均已实测）

| 类别 | 能力 | 典型工具 |
|---|---|---|
| 文件 | 写/读/建/删 | `write_file` / `read_file` / `create_file` / `delete_file` |
| 编辑器 | 打开、光标精确定位 | `open_file` / `open_file_at_position` |
| 搜索 | 内容 grep、跨文件符号 | `search_files` / `get_workspace_symbols` |
| LSP/诊断 | 符号树、悬停签名、诊断 | `get_document_symbols` / `get_hover` / `get_diagnostics` |
| 命令/终端 | 执行 VS Code 命令、集成终端跑命令 | `execute_command` / `execute_in_terminal` |
| 调试 | 断点、启动/停止、变量/调用栈 | `add_breakpoint` / `start_debugging` / `get_debug_variables` |

**实测亮点**：
- `get_hover` 在光标处拿到 `def multiply(a: Any, b: Any) -> Any` + 文档字符串（IntelliSense 真的通了）。
- 调试时 `get_debug_variables` 在断点暂停态拿到 `a=2, b=3`，`get_stack_trace` 拿到 `add(9) → main(18) → module(24)`。

---

## 使用前提（4 条，缺一不可）

1. **VS Code ≥ 1.99**，且 `code` 命令在系统 PATH（`code --version` 能出结果）。
2. **安装 VS Code 连接器扩展**：本方案依赖第三方扩展 [nabheet/vscode-ide-mcp](https://marketplace.visualstudio.com/items?itemName=nabheet.vscode-ide-mcp)（MIT，Marketplace 可装）把 VS Code 暴露成标准 MCP server：
   ```bash
   code --install-extension nabheet.vscode-ide-mcp --force
   ```
   扩展在 VS Code 启动时自动起服务，默认 `http://127.0.0.1:9876/mcp`（端口被占会扫 9876–9880），**只绑 127.0.0.1 回环，不对外网开放**，无需改 settings.json。
3. **WorkBuddy 接入**：在 `~/.workbuddy/mcp.json` 加：
   ```json
   "vscode": { "url": "http://127.0.0.1:9876/mcp" }
   ```
   （端口以实际监听为准；用 `127.0.0.1` 不是 `localhost`）并在连接器页**信任** vscode，确认工具列表出现 `mcp__vscode__*`。
4. **VS Code 打开一个项目窗口**：扩展服务与 LSP/诊断/调试能力都依赖"有 workspace 打开"。

---

## 安装这个 skill

- **WorkBuddy 市场**：搜索 `vscode-mcp-control` 一键安装。
- **手动**：把本目录放到 `~/.workbuddy/skills/vscode-mcp-control/`（`SKILL.md` 必备）。

---

## 关于"VS Code 连接器"本身（重要澄清）

> ⚠️ VS Code **官方不能**被外部 AI 直接连接——`code --help` 的子命令只有 `chat / serve-web / agent / tunnel`，**没有 `mcp`**。`"command":"code","args":["mcp"]` 会报 `MCP error -32000: Connection closed`。
>
> 本方案用的是 **第三方扩展 nabheet/vscode-ide-mcp** 把 VS Code 暴露成 MCP server。这个 skill 封装的是"怎么可靠地使用它"。如果你想要一个**完全自己掌控、可署名的 VS Code MCP 扩展**，那是另一项工程（TypeScript 扩展开发 + 打包），可在此基础上扩展。

---

## 已知限制（已验证，有绕过法）

- **终端回显抓不到**：`get_terminal_output` 常报 "requires shell integration"。绕过：让终端命令把输出重定向到工作区内文件再 `read_file` 读回（已实测 `python --version` → `Python 3.13.12`）。
  **根治（推荐）**：开启 VS Code 的 shell integration——`设置(JSON)` 加 `"terminal.integrated.shellIntegration.enabled": true`（PowerShell/cmd 默认已支持；Bash 在 VS Code 1.93+ 默认开启）。开启后可直接抓回显，无需重定向绕过。
- **read_file 受 workspace 沙箱限制**：只能读工作区内的文件，区外会报 `resolves outside the workspace`。临时文件写到工作区内（带 `_diag` 前缀）。
- **没有 `get_open_editors` 工具**：已开编辑器用 `open_file` 的返回确认即可。

更多踩坑与完整工具参数见 `SKILL.md`。

---

## 一键健康检查（自动诊断本地前提）

随附 `healthcheck.ps1`，一键跑 S1–S3 本地检查并定位连不上的故障点：

```powershell
powershell -ExecutionPolicy Bypass -File healthcheck.ps1
```

它检查 code 命令、扩展安装、9876–9880 端口监听、mcp.json 端口匹配，并给出逐项修复提示。S4/S5 仍需在 WorkBuddy 侧确认。

## 进阶：完全自托管（fork，可选）

底层依赖 `nabheet/vscode-ide-mcp`（MIT，个人维护）。想彻底去第三方依赖并署名，推荐 **fork 而非从零重写**（nabheet 已 MIT 开源，从零重写是重复造轮子）：

1. Fork https://github.com/nabheet/vscode-mcp-server ，你即维护者。
2. 可加缺失工具（如 `get_open_editors`）、锁版本、改默认端口。
3. 本地打包 `code --install-extension <你的.vsix> --force`，mcp.json 端口不变。
4. 本 skill 其余用法不变。

如此同时解决"第三方依赖风险"和"能力受限"两个卡脖子问题，成本远低于从零写扩展。

## 许可证

本 skill 文档：MIT（与底层连接器扩展一致）。底层连接器为 [nabheet/vscode-ide-mcp](https://github.com/nabheet/vscode-mcp-server)（MIT）。
