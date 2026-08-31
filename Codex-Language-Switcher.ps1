[CmdletBinding()]
param(
    [string] $ConfigPath
)

$ErrorActionPreference = 'Stop'

if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$PSCommandPath`"")
    if ($ConfigPath) { $arguments += @('-ConfigPath', "`"$ConfigPath`"") }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Import-Module (Join-Path $PSScriptRoot 'src\CodexLanguage.Core.psm1') -Force

if (-not $ConfigPath) {
    $ConfigPath = Get-CodexConfigPath
}

[xml] $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Codex Language Switcher"
        Width="900" Height="620" MinWidth="820" MinHeight="570"
        WindowStartupLocation="CenterScreen" WindowStyle="None"
        AllowsTransparency="True" Background="Transparent" ResizeMode="CanResizeWithGrip">
  <Window.Resources>
    <Style x:Key="IconButton" TargetType="Button">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="#AFC0DC"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontSize" Value="18"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bg" Background="{TemplateBinding Background}" CornerRadius="10" Padding="10,5">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bg" Property="Background" Value="#26324B"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="LocaleButton" TargetType="Button">
      <Setter Property="Background" Value="#121B2D"/>
      <Setter Property="Foreground" Value="#EAF1FF"/>
      <Setter Property="BorderBrush" Value="#263754"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="20"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="card" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="16" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="card" Property="Background" Value="#18253C"/>
                <Setter TargetName="card" Property="BorderBrush" Value="#5169FF"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Border CornerRadius="24" BorderThickness="1" BorderBrush="#31415F" Background="#0A1020">
    <Border.Effect><DropShadowEffect BlurRadius="34" ShadowDepth="8" Opacity="0.38" Color="#000713"/></Border.Effect>
    <Grid>
      <Grid.RowDefinitions><RowDefinition Height="58"/><RowDefinition Height="*"/></Grid.RowDefinitions>

      <Border x:Name="TitleBar" Grid.Row="0" Background="#0E1729" CornerRadius="24,24,0,0">
        <Grid Margin="18,0,12,0">
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <Border Width="31" Height="31" CornerRadius="10" Margin="0,0,11,0">
              <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                  <GradientStop Color="#5B6CFF" Offset="0"/><GradientStop Color="#16C5B7" Offset="1"/>
                </LinearGradientBrush>
              </Border.Background>
              <TextBlock Text="文" FontSize="16" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <TextBlock Text="Codex Language Switcher" Foreground="#F1F5FF" FontSize="15" FontWeight="SemiBold" VerticalAlignment="Center"/>
            <Border Background="#1D2A41" CornerRadius="8" Margin="12,0,0,0" Padding="8,3">
              <TextBlock Text="Windows" Foreground="#8FA4C4" FontSize="10" FontWeight="SemiBold"/>
            </Border>
          </StackPanel>
          <StackPanel Grid.Column="1" Orientation="Horizontal">
            <Button x:Name="MinimizeButton" Content="—" Style="{StaticResource IconButton}" Width="42"/>
            <Button x:Name="CloseButton" Content="×" Style="{StaticResource IconButton}" Width="42"/>
          </StackPanel>
        </Grid>
      </Border>

      <Grid Grid.Row="1" Margin="42,30,42,34">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/><RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Grid Grid.Row="0">
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <StackPanel>
            <TextBlock Text="让 Codex 说中文" Foreground="#F5F7FF" FontSize="31" FontWeight="Bold"/>
            <TextBlock Text="一键切换界面语言 · 自动备份 · 随时恢复" Foreground="#8FA4C4" FontSize="14" Margin="0,8,0,0"/>
          </StackPanel>
          <Border Grid.Column="1" Background="#102A2B" BorderBrush="#1B5753" BorderThickness="1" CornerRadius="14" Padding="14,8" VerticalAlignment="Center">
            <StackPanel Orientation="Horizontal">
              <Ellipse Width="8" Height="8" Fill="#39D9B0" Margin="0,0,8,0"/>
              <TextBlock x:Name="CurrentLocaleText" Text="正在检测…" Foreground="#80E8CD" FontSize="12" FontWeight="SemiBold"/>
            </StackPanel>
          </Border>
        </Grid>

        <Border Grid.Row="1" Background="#0D1627" BorderBrush="#1E2D46" BorderThickness="1" CornerRadius="15" Margin="0,25,0,22" Padding="16,12">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <Border Width="34" Height="34" CornerRadius="10" Background="#192844">
              <TextBlock Text="⚙" FontSize="16" Foreground="#8EA4FF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <StackPanel Grid.Column="1" Margin="12,0">
              <TextBlock Text="配置文件" Foreground="#8598B8" FontSize="11"/>
              <TextBlock x:Name="ConfigPathText" TextTrimming="CharacterEllipsis" Foreground="#DDE6F7" FontSize="12" Margin="0,3,0,0"/>
            </StackPanel>
            <Button x:Name="OpenFolderButton" Grid.Column="2" Content="打开目录" Foreground="#AFC1DE" Background="#17233A"
                    BorderThickness="0" Padding="14,7" Cursor="Hand" VerticalAlignment="Center"/>
          </Grid>
        </Border>

        <TextBlock Grid.Row="2" Text="选择界面语言" Foreground="#C7D3E9" FontSize="13" FontWeight="SemiBold"/>

        <Grid Grid.Row="3" Margin="0,13,0,20">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/><ColumnDefinition Width="12"/><ColumnDefinition Width="*"/>
            <ColumnDefinition Width="12"/><ColumnDefinition Width="*"/><ColumnDefinition Width="12"/><ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
          <Button x:Name="ZhCnButton" Grid.Column="0" Tag="zh-CN" Style="{StaticResource LocaleButton}">
            <StackPanel><TextBlock Text="简" FontSize="29" FontWeight="Bold"/><TextBlock Text="简体中文" FontSize="14" FontWeight="SemiBold" Margin="0,12,0,0"/><TextBlock Text="zh-CN" Foreground="#7388A8" FontSize="11" Margin="0,5,0,0"/></StackPanel>
          </Button>
          <Button x:Name="ZhTwButton" Grid.Column="2" Tag="zh-TW" Style="{StaticResource LocaleButton}">
            <StackPanel><TextBlock Text="繁" FontSize="29" FontWeight="Bold"/><TextBlock Text="繁體中文" FontSize="14" FontWeight="SemiBold" Margin="0,12,0,0"/><TextBlock Text="zh-TW" Foreground="#7388A8" FontSize="11" Margin="0,5,0,0"/></StackPanel>
          </Button>
          <Button x:Name="EnUsButton" Grid.Column="4" Tag="en-US" Style="{StaticResource LocaleButton}">
            <StackPanel><TextBlock Text="EN" FontSize="27" FontWeight="Bold"/><TextBlock Text="English" FontSize="14" FontWeight="SemiBold" Margin="0,12,0,0"/><TextBlock Text="en-US" Foreground="#7388A8" FontSize="11" Margin="0,5,0,0"/></StackPanel>
          </Button>
          <Button x:Name="AutoButton" Grid.Column="6" Tag="auto" Style="{StaticResource LocaleButton}">
            <StackPanel><TextBlock Text="A✦" FontSize="27" FontWeight="Bold"/><TextBlock Text="跟随系统" FontSize="14" FontWeight="SemiBold" Margin="0,12,0,0"/><TextBlock Text="Auto" Foreground="#7388A8" FontSize="11" Margin="0,5,0,0"/></StackPanel>
          </Button>
        </Grid>

        <Grid Grid.Row="4">
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="14"/><ColumnDefinition Width="240"/></Grid.ColumnDefinitions>
          <StackPanel VerticalAlignment="Center">
            <TextBlock x:Name="StatusText" Text="选择语言后点击应用" Foreground="#93A5C2" FontSize="12"/>
            <TextBlock Text="修改后请彻底退出并重新打开 Codex" Foreground="#596D8D" FontSize="10" Margin="0,4,0,0"/>
          </StackPanel>
          <Button x:Name="RestoreButton" Grid.Column="1" Content="恢复上次备份" Foreground="#B8C6DC" Background="#172238"
                  BorderBrush="#2A3954" BorderThickness="1" Padding="18,12" Cursor="Hand"/>
          <Button x:Name="ApplyButton" Grid.Column="3" Foreground="White" BorderThickness="0" Padding="22,13" Cursor="Hand" FontWeight="SemiBold">
            <Button.Background>
              <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                <GradientStop Color="#596BFF" Offset="0"/><GradientStop Color="#3989F7" Offset="0.55"/><GradientStop Color="#13BFAF" Offset="1"/>
              </LinearGradientBrush>
            </Button.Background>
            <TextBlock Text="应用语言设置  →"/>
          </Button>
        </Grid>
      </Grid>
    </Grid>
  </Border>
</Window>
'@

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$names = @(
    'TitleBar', 'MinimizeButton', 'CloseButton', 'CurrentLocaleText', 'ConfigPathText',
    'OpenFolderButton', 'ZhCnButton', 'ZhTwButton', 'EnUsButton', 'AutoButton',
    'StatusText', 'RestoreButton', 'ApplyButton'
)
foreach ($name in $names) {
    Set-Variable -Name $name -Value $window.FindName($name)
}

$script:selectedLocale = $null
$localeButtons = @($ZhCnButton, $ZhTwButton, $EnUsButton, $AutoButton)

function Get-LocaleLabel([AllowNull()][string] $Locale) {
    switch ($Locale) {
        'zh-CN' { '当前：简体中文' }
        'zh-TW' { '当前：繁體中文' }
        'en-US' { '当前：English' }
        default { '当前：跟随系统' }
    }
}

function Set-SelectedLocale([AllowNull()][string] $Locale) {
    $script:selectedLocale = $Locale
    foreach ($button in $localeButtons) {
        $button.BorderBrush = '#263754'
        $button.BorderThickness = '1'
        $button.Background = '#121B2D'
    }

    $target = switch ($Locale) {
        'zh-CN' { $ZhCnButton }
        'zh-TW' { $ZhTwButton }
        'en-US' { $EnUsButton }
        default { $AutoButton }
    }
    $target.BorderBrush = '#5B78FF'
    $target.BorderThickness = '2'
    $target.Background = '#182642'
}

function Refresh-Status {
    $locale = Get-CodexLocaleOverride -ConfigPath $ConfigPath
    $CurrentLocaleText.Text = Get-LocaleLabel $locale
    Set-SelectedLocale $locale
}

$ConfigPathText.Text = $ConfigPath
Refresh-Status

$TitleBar.Add_MouseLeftButtonDown({
    if ($_.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) { $window.DragMove() }
})
$MinimizeButton.Add_Click({ $window.WindowState = 'Minimized' })
$CloseButton.Add_Click({ $window.Close() })

foreach ($button in $localeButtons) {
    $button.Add_Click({
        $value = [string] $_.Source.Tag
        Set-SelectedLocale $(if ($value -eq 'auto') { $null } else { $value })
        $StatusText.Text = '已选择，点击“应用语言设置”保存'
        $StatusText.Foreground = '#A9BAFF'
    })
}

$OpenFolderButton.Add_Click({
    $directory = Split-Path -Parent $ConfigPath
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    Start-Process explorer.exe -ArgumentList $directory
})

$ApplyButton.Add_Click({
    try {
        $ApplyButton.IsEnabled = $false
        $StatusText.Text = '正在写入并创建备份…'
        $result = Set-CodexLocaleOverride -ConfigPath $ConfigPath -Locale $script:selectedLocale
        Refresh-Status
        $StatusText.Text = if ($result.BackupPath) { '✓ 设置成功，原配置已备份' } else { '✓ 设置成功' }
        $StatusText.Foreground = '#52D6B7'
    }
    catch {
        $StatusText.Text = "设置失败：$($_.Exception.Message)"
        $StatusText.Foreground = '#FF7C93'
    }
    finally {
        $ApplyButton.IsEnabled = $true
    }
})

$RestoreButton.Add_Click({
    try {
        $restored = Restore-LatestCodexConfigBackup -ConfigPath $ConfigPath
        Refresh-Status
        $StatusText.Text = "✓ 已恢复：$(Split-Path -Leaf $restored)"
        $StatusText.Foreground = '#52D6B7'
    }
    catch {
        $StatusText.Text = $_.Exception.Message
        $StatusText.Foreground = '#FFB56B'
    }
})

[void] $window.ShowDialog()
