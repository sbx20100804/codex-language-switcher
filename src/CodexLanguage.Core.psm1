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
        if ($line -match '^\s*\[([^]]+)\]\s*$') {
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
        [ValidateSet('zh-CN', 'zh-TW', 'en-US', $null)]
        [string] $Locale
    )

    $parent = Split-Path -Parent $ConfigPath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

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
        if ($lines[$i] -match '^\s*\[desktop\]\s*$') {
            $desktopStart = $i
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                if ($lines[$j] -match '^\s*\[[^]]+\]\s*$') {
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
        while ($result.Count -gt 0 -and [string]::IsNullOrWhiteSpace($result[$result.Count - 1])) {
            $result.RemoveAt($result.Count - 1)
        }

        if ($result.Count -gt 0) { $result.Add('') }
        $result.Add('[desktop]')
        if ($null -ne $Locale) {
            $result.Add(('localeOverride = "{0}"' -f $Locale))
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

        if ($null -eq $Locale) {
            if ($localeLine -ge 0) {
                $result.RemoveAt($localeLine)
            }
        }
        elseif ($localeLine -ge 0) {
            $result[$localeLine] = ('localeOverride = "{0}"' -f $Locale)
        }
        else {
            $result.Insert($desktopStart + 1, ('localeOverride = "{0}"' -f $Locale))
        }
    }

    $updatedText = [string]::Join($newline, $result)
    if ($updatedText.Length -gt 0 -and -not $updatedText.EndsWith($newline)) {
        $updatedText += $newline
    }

    $backupPath = $null
    if (Test-Path -LiteralPath $ConfigPath) {
        $backupDirectory = Join-Path $parent 'language-switcher-backups'
        New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        $backupPath = Join-Path $backupDirectory "config.$stamp.toml.bak"
        Copy-Item -LiteralPath $ConfigPath -Destination $backupPath -Force
    }

    if ($PSCmdlet.ShouldProcess($ConfigPath, 'Update Codex desktop locale')) {
        $tempPath = "$ConfigPath.language-switcher.tmp"
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($tempPath, $updatedText, $utf8NoBom)
        Move-Item -LiteralPath $tempPath -Destination $ConfigPath -Force
    }

    [pscustomobject]@{
        ConfigPath = $ConfigPath
        Locale     = $Locale
        BackupPath = $backupPath
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
