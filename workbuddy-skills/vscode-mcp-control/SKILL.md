---
name: vscode-mcp-control
agent_created: true
description: "让 WorkBuddy 直接驱动用户已配好插件与编译器的 VS Code：读/写/改文件、打开编辑器、全局搜索、执行 VS Code 命令、LSP（符号/悬停/诊断）、集成终端执行、断点调试（变量/调用栈）。包含已验证工具清单、正确参数、7 个真实踩坑与绕过法、S1–S5 验证流程。适用于：想复用 VSCode 里的编译器/扩展/调试器，而不是在 WorkBuddy 空 Bash 里重配一套环境。"
---

# VS Code MCP 控制

## 这是什么 / 解决什么

WorkBuddy 默认只能直接读写磁盘文件、在自带沙箱 Bash 里跑命令。**这个 skill 让你能直接驱动你那台已经配好插件、编译器、tasks、调试器的 VS Code**——也就是说，WorkBuddy 能"借用"你 VSCode 里的 Python/C++ 扩展、IntelliSense、集成终端和调试器，而不是另起炉灶重配环境。

底层靠一个第三方 VS Code 扩展把 VSCode 暴露成标准 MCP server，WorkBuddy 连上去即可。本 skill 是这套方案的**已验证用法封装**：哪些工具真的能用、参数怎么传、踩过哪些坑、怎么验证连通。

## 使用前提（4 条，缺一不可）

1. **VS Code ≥ 1.99**，且 `code` 命令在系统 PATH（`code --version` 能出结果）。
2. **已装扩展** `nabheet/vscode-ide-mcp`（第三方，MIT，Marketplace 可装）：
   `code --install-extension nabheet.vscode-ide-mcp --force`
   它在 VS Code 启动时自动起一个 MCP 服务，默认 `http://127.0.0.1:9876/mcp`（端口被占会扫 9876–9880），**只绑 127.0.0.1 回环，不对外网开放**，无需改 settings.json。
3. **WorkBuddy 侧已接入**：`~/.workbuddy/mcp.json` 加 `"vscode": { "url": "http://127.0.0.1:9876/mcp" }`（端口以实际监听为准），并在连接器页**信任** vscode，确认工具列表出现 `mcp__vscode__*`。
4. **VS Code 打开着一个项目窗口**：扩展服务只在"有 workspace 打开 + 扩展激活"后才起来；LSP 诊断、符号、调试等能力也都需要先打开项目。

## 能力清单（六大类，均经实测）

- **文件**：写/读/建/删（`write_file` / `read_file` / `create_file` / `delete_file` 移回收站）
- **编辑器**：打开、精确定位光标（`open_file` / `open_file_at_position`）
- **搜索**：内容 grep、跨文件符号（`search_files` / `get_workspace_symbols`）
- **LSP/诊断**：符号树、悬停签名、诊断（`get_document_symbols` / `get_hover` / `get_diagnostics`）
- **命令/终端**：执行任意 VS Code 命令、在集成终端跑命令（`execute_command` / `execute_in_terminal`）
- **调试**：下断点、启动/停止、看变量与调用栈（`add_breakpoint` / `start_debugging` / `get_debug_variables` / `get_stack_trace`）

## 何时用

- 用户想让我直接操作他已配置好的 VS Code（编译器、Python/C++ 扩展、IntelliSense、tasks、调试器）。
- 需要在 VSCode 集成终端跑命令（继承 VSCode 的 PATH 与环境）。
- 需要在 VSCode 里下断点、看变量/调用栈地调试代码。

## 已验证可用工具（参数要点）

- **文件**：`write_file{path,content[,workspaceFolder]}`（创建/覆盖）、`read_file{path}`、`read_files{paths[]}`、`create_file{path}`（建空文件，会建父目录）、`delete_file{path}`（**移入回收站**）、`reveal_in_explorer{path}`
- **编辑器**：`open_file{path}`（返回 "Opened … at line 1"）、`open_file_at_position{path,line,column}`（1-indexed）、`open_file_at_line`、`close_editor`、`close_all_editors`、`focus_editor`、`select_lines`
- **搜索**：`search_files{query,include,exclude,useRegex,caseSensitive,maxResults,contextLines}`（grep，返回 文件/行/列/匹配行文本）、`get_workspace_symbols{query}`
- **LSP/诊断**：`get_document_symbols{}`（**当前激活文档**的符号树）、`get_hover{}`（**光标处**悬停，需先 `open_file_at_position` 定位）、`get_diagnostics{uri}`（uri 形如 `file:///c:/...`）、`get_completions`、`find_references`、`go_to_definition`、`get_code_actions`、`rename_symbol`
- **命令**：`execute_command{command,args[]}`（执行任意 VS Code 命令 ID，如 `workbench.action.toggleSidebarVisibility`；返回字符串或空）
- **终端**：`execute_in_terminal{command}`（异步，返回 terminal 名）、`create_terminal`、`get_terminal_output{name,maxChars}`
- **调试**：`add_breakpoint{path,line,condition?,hitCondition?}`、`list_breakpoints`、`remove_breakpoint`、`start_debugging{configName,folder?}`、`stop_debugging`、`get_debug_variables{}`（**需暂停态**）、`get_stack_trace{}`、`evaluate_in_debug_console`、`continue`/`step_into`/`step_over`/`step_out`
- **工作区**：`list_workspaces`、`get_workspace_folders`、`add/remove/update_workspace_folder`
- **其它**：`list_logs`、`read_log`

## ⚠️ 真实踩坑（必看，已逐个验证）

1. **`code mcp` 是假的**：VS Code 官方**没有**把自身作为 MCP server 的命令（`code --help` 子命令只有 `chat / serve-web / agent / tunnel`）。想让外部 AI 连 VSCode，只能装第三方扩展（如 nabheet/vscode-ide-mcp）。`"command":"code","args":["mcp"]` 会报 `MCP error -32000: Connection closed`（进程秒退）。
2. **终端回显抓不到**：`get_terminal_output` 常报 "requires shell integration"——很多 VSCode 终端没启用 shell 集成。绕过法：让终端命令把输出重定向到**工作区内**文件（`cmd > file 2>&1`），再用 `read_file` 读回。已实测拿到 `python --version` 的 `Python 3.13.12`、`6*7=42`。
3. **read_file 受 workspace 沙箱限制**：只能读工作区内的文件，读区外报 `resolves outside the workspace`。临时文件写到工作区内（带 `_diag` 前缀）。
4. **execute_command 不要传 `return` 字段**：只需 `{command:"..."}`（可选 `args`）。传多余字段会报错。
5. **没有 `get_open_editors` 工具**：列举已开编辑器用 `open_file` 的返回确认即可。
6. **端口可能不在 9876**：扩展被占用会扫 9876–9880，mcp.json 的 URL 端口以实测为准；一律用 `127.0.0.1` 不用 `localhost`。
7. **调试需先有 launch.json**（在 `.vscode/`，**写前先 `read_file` 确认不存在**，勿覆盖用户配置）、configName 要匹配；Python 用 `type:"debugpy"`。断点命中后才能 `get_debug_variables`/`get_stack_trace`。注意 `list_breakpoints` 在刚加断点后可能异步返回 "No breakpoints"（显示延迟），以调试实际暂停为准。

## 连通验证清单（S1–S5，改完必须实测，不能只看 connected）

- **S1** 安装：`code --list-extensions` 含 `nabheet.vscode-ide-mcp`
- **S2** 端口：`127.0.0.1:9876`（或实测端口）处于 LISTENING
- **S3** 配置：`python -c "import json; json.load(open(mcp.json))"` 通过，`vscode` 为 `mcpServers` 直接子项、url 型、端口=实测端口
- **S4** 连通：工具列表出现 `mcp__vscode__*`
- **S5** 功能真实动作（任选其一证明真用上 VSCode 环境）：`read_file` 读回真实文件 / 终端跑 `python --version` 重定向回读 / 调试拿到变量

## 回滚

- 配置：`cp ~/.workbuddy/mcp.json.backup.* ~/.workbuddy/mcp.json`
- 扩展：`code --uninstall-extension nabheet.vscode-ide-mcp`

## 快速验证脚本（连通后跑一遍）

```
list_workspaces            → 返回真实 VSCode 窗口（PID）
get_workspace_folders      → 返回打开的项目
write_file(demo.py, ...)   → 建测试文件
read_file(demo.py)         → 读回
open_file_at_position(demo.py,12,5) → 定位
get_document_symbols()     → 符号树
get_hover()                → 悬停签名
search_files(query)        → grep
execute_in_terminal(...)   → 终端（重定向+read_file 取输出）
delete_file(...)           → 清理
```
