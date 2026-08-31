$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot '..\Codex-Language-Switcher.ps1'
$source = [System.IO.File]::ReadAllText($scriptPath)
$match = [regex]::Match($source, "(?s)\[xml\]\s+\`$xaml\s*=\s*@'\r?\n(.*?)\r?\n'@")
if (-not $match.Success) {
    throw 'XAML block not found.'
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
[xml] $xaml = $match.Groups[1].Value
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

if ($window.Title -ne 'Codex Language Switcher') {
    throw 'Window title validation failed.'
}

foreach ($elementName in @('ZhCnButton', 'ZhTwButton', 'EnUsButton', 'AutoButton', 'ApplyButton')) {
    if (-not $window.FindName($elementName)) {
        throw "Missing UI element: $elementName"
    }
}

Write-Host 'PASS: WPF XAML successfully loaded.' -ForegroundColor Green
