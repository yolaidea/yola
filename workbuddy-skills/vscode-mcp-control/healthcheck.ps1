<#
  vscode-mcp-control · 一键健康检查脚本
  作用：自动检查本地前提（S1 扩展 / S2 端口 / S3 配置），定位连不上 VS Code 的故障点。
  用法：powershell -ExecutionPolicy Bypass -File healthcheck.ps1
  说明：本脚本只查"本机"前提。S4（WorkBuddy 工具列表出现 mcp__vscode__*）
        和 S5（真实功能动作）需在 WorkBuddy 连接器页确认，脚本会给出提示。
#>

$ErrorActionPreference = 'SilentlyContinue'

# 状态符号
$tick = [char]0x2714   # ✔
$cross = [char]0x2716  # ✖
$warn = [char]0x26A0   # ⚠

function Report($mark, $color, $title, $detail) {
    Write-Host ("  {0} {1}" -f $mark, $title) -ForegroundColor $color
    if ($detail) {
        Write-Host ("      {0}" -f $detail) -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== vscode-mcp-control 健康检查 ===" -ForegroundColor Cyan
Write-Host ""

# ---------- S0: code 命令可用性 ----------
Write-Host "[S0] VS Code 命令 (code) 是否可用" -ForegroundColor White
$codeVer = & code --version 2>$null
if ($LASTEXITCODE -eq 0 -and $codeVer) {
    Report $tick Green "code 命令正常" ("版本: " + ($codeVer | Select-Object -First 1))
} else {
    Report $cross Red "code 命令不可用" "请在系统 PATH 中加入 VS Code，或重新安装 VS Code 时勾选 'Add to PATH'"
    Write-Host ""
    Write-Host "结论: 基础命令缺失，后续检查跳过。请先修复 PATH 后重跑。" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# ---------- S1: 扩展是否已安装 ----------
Write-Host "[S1] 扩展 nabheet.vscode-ide-mcp 是否已安装" -ForegroundColor White
$exts = & code --list-extensions 2>$null
$hasExt = ($null -ne $exts) -and (($exts -join "`n") -match 'nabheet\.vscode-ide-mcp')
if ($hasExt) {
    Report $tick Green "扩展已安装" "nabheet.vscode-ide-mcp"
} else {
    Report $cross Red "扩展未安装" "运行: code --install-extension nabheet.vscode-ide-mcp --force"
}

# ---------- S2: MCP 服务端口监听 (9876-9880) ----------
Write-Host "[S2] MCP 服务端口监听 (127.0.0.1:9876-9880)" -ForegroundColor White
$listening = @()
foreach ($p in 9876..9880) {
    $up = Test-NetConnection -ComputerName 127.0.0.1 -Port $p -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($up) { $listening += $p }
}
if ($listening.Count -gt 0) {
    Report $tick Green ("服务在监听, 端口: " + ($listening -join ", ")) "VS Code 已启动且扩展已激活"
} else {
    Report $cross Red "未检测到监听端口" "请: ① 打开 VS Code ② 打开一个项目窗口 ③ 等待扩展自动起服务(几秒)"
}

# ---------- S3: mcp.json 配置 + 端口匹配 ----------
Write-Host "[S3] WorkBuddy mcp.json 配置" -ForegroundColor White
$mcpPath = Join-Path $env:USERPROFILE '.workbuddy\mcp.json'
if (-not (Test-Path $mcpPath)) {
    Report $cross Red "未找到 mcp.json" ("期望路径: " + $mcpPath)
} else {
    try {
        $cfg = Get-Content $mcpPath -Raw | ConvertFrom-Json
        $vs = $null
        if ($cfg.mcpServers -and $cfg.mcpServers.vscode) { $vs = $cfg.mcpServers.vscode }
        if (-not $vs) {
            Report $cross Red "mcp.json 中缺少 vscode 条目" '请添加: "vscode": { "url": "http://127.0.0.1:9876/mcp" }'
        } elseif (-not $vs.url) {
            Report $cross Red "vscode 条目缺少 url" '需要 "url": "http://127.0.0.1:<实测端口>/mcp"'
        } else {
            $uri = $null
            try { $uri = [System.Uri]$vs.url } catch {}
            if ($null -eq $uri) {
                Report $cross Red "vscode.url 不是合法 URL" $vs.url
            } else {
                $port = $uri.Port
                if ($listening -contains $port) {
                    Report $tick Green ("url 端口匹配: " + $vs.url) "配置端口与本地监听一致"
                } elseif ($listening.Count -gt 0) {
                    Report $warn Yellow ("url 端口($port) 与监听端口不一致" ) ("本地监听: " + ($listening -join ",") + "; 请修正 mcp.json 端口")
                } else {
                    Report $warn Yellow ("url 端口=$port, 但本地无监听" ) "先解决 S2(打开 VS Code), 再回头确认端口"
                }
            }
        }
    } catch {
        Report $cross Red "mcp.json JSON 解析失败" $_.Exception.Message
    }
}

# ---------- 汇总 ----------
Write-Host ""
Write-Host "=== 故障定位速查 ===" -ForegroundColor Cyan
Write-Host "  • S1 失败  -> 装扩展: code --install-extension nabheet.vscode-ide-mcp --force" -ForegroundColor Gray
Write-Host "  • S2 失败  -> 打开 VS Code + 打开一个项目窗口(扩展需 workspace 才起服务)" -ForegroundColor Gray
Write-Host "  • S3 失败  -> 修正 ~/.workbuddy/mcp.json 的 vscode.url 端口(以 S2 实测为准), 用 127.0.0.1" -ForegroundColor Gray
Write-Host ""
Write-Host "=== 后续 (需在 WorkBuddy 侧确认) ===" -ForegroundColor Cyan
Write-Host "  [S4] 连接器页信任 vscode, 工具列表出现 mcp__vscode__*" -ForegroundColor Gray
Write-Host "  [S5] 跑一次真实动作: read_file 读回文件 / 终端 python --version 重定向回读 / 调试拿变量" -ForegroundColor Gray
Write-Host ""
