Set-StrictMode -Version Latest

function Get-CodexConfigPath {
    [CmdletBinding()]
    param()

    $codexHome = if ($env:CODEX_HOME) {
        $env:CODEX_HOME
    }
    else {
        Join-Path $HOME '.codex'
    }

    Join-Path $codexHome 'config.toml'
}

function Get-CodexLocaleOverride {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ConfigPath
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        return $null
    }

    $lines = [System.IO.File]::ReadAllLines($ConfigPath)
    $inDesktopSection = $false

    foreach ($line in $lines) {
        if ($line -match '^\s*\[([^]]+)\]\s*(?:#.*)?$') {
            $inDesktopSection = ($Matches[1] -eq 'desktop')
            continue
        }

        if ($inDesktopSection -and $line -match '^\s*localeOverride\s*=\s*["'']([^"'']+)["'']\s*(?:#.*)?$') {
            return $Matches[1]
        }
    }

    return $null
}

function Set-CodexLocaleOverride {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string] $ConfigPath,

        [AllowNull()]
        [AllowEmptyString()]
        [ValidateSet('zh-CN', 'zh-TW', 'en-US', '')]
        [string] $Locale,

        [ValidateRange(1, 100)]
        [int] $BackupLimit = 20
    )

    $parent = Split-Path -Parent $ConfigPath
    if ([string]::IsNullOrWhiteSpace($parent)) { $parent = (Get-Location).Path }
    $normalizedLocale = if ([string]::IsNullOrEmpty($Locale)) { $null } else { $Locale }

    $originalText = if (Test-Path -LiteralPath $ConfigPath) {
        [System.IO.File]::ReadAllText($ConfigPath)
    }
    else {
        ''
    }

    $newline = if ($originalText.Contains("`r`n")) { "`r`n" } else { "`n" }
    if ($originalText.Length -gt 0) {
        [string[]] $lines = [regex]::Split($originalText, '\r?\n')
    }
    else {
        [string[]] $lines = @()
    }

    $desktopStart = -1
    $desktopEnd = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[desktop\]\s*(?:#.*)?$') {
            $desktopStart = $i
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                if ($lines[$j] -match '^\s*\[[^]]+\]\s*(?:#.*)?$') {
                    $desktopEnd = $j
                    break
                }
            }
            break
        }
    }

    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines) { $result.Add($line) }

    if ($desktopStart -lt 0) {
        if ($null -eq $normalizedLocale) {
            return [pscustomobject]@{
                ConfigPath  = $ConfigPath
                Locale      = $normalizedLocale
                BackupPath  = $null
                Changed     = $false
                WouldChange = $false
            }
        }

        while ($result.Count -gt 0 -and [string]::IsNullOrWhiteSpace($result[$result.Count - 1])) {
            $result.RemoveAt($result.Count - 1)
        }

        if ($result.Count -gt 0) { $result.Add('') }
        $result.Add('[desktop]')
        if ($null -ne $normalizedLocale) {
            $result.Add(('localeOverride = "{0}"' -f $normalizedLocale))
        }
    }
    else {
        $localeLine = -1
        for ($i = $desktopStart + 1; $i -lt $desktopEnd; $i++) {
            if ($result[$i] -match '^\s*localeOverride\s*=') {
                $localeLine = $i
                break
            }
        }

        if ($null -eq $normalizedLocale) {
            if ($localeLine -ge 0) {
                $result.RemoveAt($localeLine)
            }
        }
        elseif ($localeLine -ge 0) {
            if ($result[$localeLine] -match '^(\s*localeOverride\s*=\s*)["''][^"'']+["''](\s*(?:#.*)?)$') {
                $result[$localeLine] = ('{0}"{1}"{2}' -f $Matches[1], $normalizedLocale, $Matches[2])
            }
            else {
                $result[$localeLine] = ('localeOverride = "{0}"' -f $normalizedLocale)
            }
        }
        else {
            $result.Insert($desktopStart + 1, ('localeOverride = "{0}"' -f $normalizedLocale))
        }
    }

    $updatedText = [string]::Join($newline, $result)
    if ($updatedText.Length -gt 0 -and -not $updatedText.EndsWith($newline)) {
        $updatedText += $newline
    }

    $contentChanged = $updatedText -cne $originalText
    if (-not $contentChanged) {
        return [pscustomobject]@{
            ConfigPath  = $ConfigPath
            Locale      = $normalizedLocale
            BackupPath  = $null
            Changed     = $false
            WouldChange = $false
        }
    }

    $backupPath = $null
    $changed = $false

    if ($PSCmdlet.ShouldProcess($ConfigPath, 'Update Codex desktop locale')) {
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        $backupDirectory = Join-Path $parent 'language-switcher-backups'
        if (Test-Path -LiteralPath $ConfigPath) {
            New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
            $backupPath = Join-Path $backupDirectory "config.$stamp.toml.bak"
            Copy-Item -LiteralPath $ConfigPath -Destination $backupPath -Force
        }

        $tempPath = "$ConfigPath.language-switcher.$([guid]::NewGuid().ToString('N')).tmp"
        try {
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            [System.IO.File]::WriteAllText($tempPath, $updatedText, $utf8NoBom)
            Move-Item -LiteralPath $tempPath -Destination $ConfigPath -Force
            $changed = $true
        }
        finally {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }

        if (Test-Path -LiteralPath $backupDirectory) {
            Get-ChildItem -LiteralPath $backupDirectory -Filter 'config.*.toml.bak' -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTimeUtc -Descending |
                Select-Object -Skip $BackupLimit |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }

    [pscustomobject]@{
        ConfigPath  = $ConfigPath
        Locale      = $normalizedLocale
        BackupPath  = $backupPath
        Changed     = $changed
        WouldChange = $contentChanged
    }
}

function Restore-LatestCodexConfigBackup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string] $ConfigPath
    )

    $backupDirectory = Join-Path (Split-Path -Parent $ConfigPath) 'language-switcher-backups'
    $latest = Get-ChildItem -LiteralPath $backupDirectory -Filter 'config.*.toml.bak' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if (-not $latest) {
        throw '没有找到可恢复的配置备份。'
    }

    if ($PSCmdlet.ShouldProcess($ConfigPath, "Restore $($latest.FullName)")) {
        if (Test-Path -LiteralPath $ConfigPath) {
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
            $undoBackup = Join-Path $backupDirectory "config.$stamp.toml.bak"
            Copy-Item -LiteralPath $ConfigPath -Destination $undoBackup -Force
        }
        Copy-Item -LiteralPath $latest.FullName -Destination $ConfigPath -Force
    }

    $latest.FullName
}

Export-ModuleMember -Function @(
    'Get-CodexConfigPath',
    'Get-CodexLocaleOverride',
    'Set-CodexLocaleOverride',
    'Restore-LatestCodexConfigBackup'
)
