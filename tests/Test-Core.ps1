$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\src\CodexLanguage.Core.psm1') -Force

function Assert-Equal($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) {
        throw "$Message`nExpected: $Expected`nActual: $Actual"
    }
}

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('codex-language-switcher-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

try {
    $configPath = Join-Path $testRoot 'config.toml'
    [System.IO.File]::WriteAllText($configPath, "model = `"gpt-test`"`r`n`r`n[desktop] # UI settings`r`n  localeOverride = 'en-US' # keep me`r`nappearanceTheme = `"system`"`r`n")

    $result = Set-CodexLocaleOverride -ConfigPath $configPath -Locale 'zh-CN'
    Assert-Equal (Get-CodexLocaleOverride -ConfigPath $configPath) 'zh-CN' '简体中文写入测试失败'
    Assert-True (Test-Path -LiteralPath $result.BackupPath) '备份创建测试失败'
    Assert-True $result.Changed '首次修改应报告 Changed=True'
    Assert-True ([System.IO.File]::ReadAllText($configPath).Contains('# keep me')) '行尾注释应被保留'

    $backupDirectory = Join-Path $testRoot 'language-switcher-backups'
    $backupCountBeforeNoOp = @(Get-ChildItem $backupDirectory -File).Count
    $noOp = Set-CodexLocaleOverride -ConfigPath $configPath -Locale 'zh-CN'
    $backupCountAfterNoOp = @(Get-ChildItem $backupDirectory -File).Count
    Assert-True (-not $noOp.Changed) '重复应用相同语言不应改写配置'
    Assert-Equal $backupCountAfterNoOp $backupCountBeforeNoOp '无变化时不应新增备份'

    Set-CodexLocaleOverride -ConfigPath $configPath -Locale 'en-US' | Out-Null
    Assert-Equal (Get-CodexLocaleOverride -ConfigPath $configPath) 'en-US' '语言替换测试失败'

    Set-CodexLocaleOverride -ConfigPath $configPath -Locale $null | Out-Null
    Assert-Equal (Get-CodexLocaleOverride -ConfigPath $configPath) $null '跟随系统测试失败'

    $newConfigPath = Join-Path $testRoot 'new\config.toml'
    $whatIf = Set-CodexLocaleOverride -ConfigPath $newConfigPath -Locale 'zh-TW' -WhatIf
    Assert-True (-not (Test-Path -LiteralPath $newConfigPath)) 'WhatIf 不应创建配置文件'
    Assert-True (-not $whatIf.Changed -and $whatIf.WouldChange) 'WhatIf 状态报告不正确'

    $autoMissingPath = Join-Path $testRoot 'auto-missing\config.toml'
    $autoMissing = Set-CodexLocaleOverride -ConfigPath $autoMissingPath -Locale $null
    Assert-True (-not $autoMissing.Changed) '缺少配置时选择跟随系统应为无操作'
    Assert-True (-not (Test-Path -LiteralPath $autoMissingPath)) '缺少配置时选择跟随系统不应创建空文件'

    Set-CodexLocaleOverride -ConfigPath $newConfigPath -Locale 'zh-TW' | Out-Null
    Assert-Equal (Get-CodexLocaleOverride -ConfigPath $newConfigPath) 'zh-TW' '新配置创建测试失败'

    $restorePath = Join-Path $testRoot 'restore\config.toml'
    Set-CodexLocaleOverride -ConfigPath $restorePath -Locale 'zh-CN' | Out-Null
    Set-CodexLocaleOverride -ConfigPath $restorePath -Locale 'en-US' | Out-Null
    Restore-LatestCodexConfigBackup -ConfigPath $restorePath | Out-Null
    Assert-Equal (Get-CodexLocaleOverride -ConfigPath $restorePath) 'zh-CN' '恢复备份测试失败'
    Restore-LatestCodexConfigBackup -ConfigPath $restorePath | Out-Null
    Assert-Equal (Get-CodexLocaleOverride -ConfigPath $restorePath) 'en-US' '恢复操作应可再次撤销'

    $retentionPath = Join-Path $testRoot 'retention\config.toml'
    Set-CodexLocaleOverride -ConfigPath $retentionPath -Locale 'zh-CN' -BackupLimit 3 | Out-Null
    foreach ($locale in @('en-US', 'zh-CN', 'zh-TW', 'en-US', 'zh-CN')) {
        Set-CodexLocaleOverride -ConfigPath $retentionPath -Locale $locale -BackupLimit 3 | Out-Null
    }
    $retentionBackupDirectory = Join-Path (Split-Path -Parent $retentionPath) 'language-switcher-backups'
    $retained = @(Get-ChildItem $retentionBackupDirectory -File)
    Assert-Equal $retained.Count 3 '备份保留数量应受 BackupLimit 限制'

    Write-Host 'PASS: 所有核心配置测试均已通过。' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
