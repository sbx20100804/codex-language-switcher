$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\src\CodexLanguage.Core.psm1') -Force

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('codex-language-switcher-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

try {
    $configPath = Join-Path $testRoot 'config.toml'
    [System.IO.File]::WriteAllText($configPath, "model = `"gpt-test`"`r`n`r`n[desktop]`r`nappearanceTheme = `"system`"`r`n")

    $result = Set-CodexLocaleOverride -ConfigPath $configPath -Locale 'zh-CN'
    if ((Get-CodexLocaleOverride -ConfigPath $configPath) -ne 'zh-CN') { throw '简体中文写入测试失败' }
    if (-not (Test-Path -LiteralPath $result.BackupPath)) { throw '备份创建测试失败' }

    Set-CodexLocaleOverride -ConfigPath $configPath -Locale 'en-US' | Out-Null
    if ((Get-CodexLocaleOverride -ConfigPath $configPath) -ne 'en-US') { throw '语言替换测试失败' }

    Set-CodexLocaleOverride -ConfigPath $configPath -Locale $null | Out-Null
    if ($null -ne (Get-CodexLocaleOverride -ConfigPath $configPath)) { throw '跟随系统测试失败' }

    $newConfigPath = Join-Path $testRoot 'new\config.toml'
    Set-CodexLocaleOverride -ConfigPath $newConfigPath -Locale 'zh-TW' | Out-Null
    if ((Get-CodexLocaleOverride -ConfigPath $newConfigPath) -ne 'zh-TW') { throw '新配置创建测试失败' }

    Write-Host 'PASS: 所有核心配置测试均已通过。' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
