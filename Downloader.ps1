[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:Root = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($env:DOWNLOADER_ROOT) {
    $env:DOWNLOADER_ROOT.TrimEnd('\')
}
else {
    (Get-Location).Path
}
$script:ToolsDir = Join-Path $script:Root 'tools'
$script:YtDlp = Join-Path $script:ToolsDir 'yt-dlp.exe'
$script:FfmpegDir = Join-Path $script:ToolsDir 'ffmpeg\bin'
$script:Ffmpeg = Join-Path $script:FfmpegDir 'ffmpeg.exe'
$script:CurrentProcess = $null
$script:LastInfo = $null
$script:OutputReadTask = $null
$script:ErrorReadTask = $null
$script:ProcessTimer = $null
$script:CancelRequested = $false
$script:CrashLog = Join-Path $script:Root 'downloader-crash.log'
$script:VersionFile = Join-Path $script:Root 'version.txt'
$script:AppVersion = if (Test-Path -LiteralPath $script:VersionFile) { (Get-Content -LiteralPath $script:VersionFile -Raw).Trim() } else { '1.0.0' }
$script:GitHubRepo = 'montazainformer-coder/informer-video-downloader'
$script:UpdateChecked = $false
$script:CurrentStage = 'idle'
$script:OutputMode = 'mp4'
$script:DownloadManifest = $null

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Video Downloader" Width="1180" Height="700" MinWidth="980" MinHeight="620"
        WindowStartupLocation="CenterScreen" Background="#0B1020" Foreground="#E8ECF5"
        FontFamily="Segoe UI">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Background" Value="#6D5DFB"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="16,10"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#151C31"/>
      <Setter Property="Foreground" Value="#F5F7FF"/>
      <Setter Property="BorderBrush" Value="#2A3557"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="11,9"/>
      <Setter Property="CaretBrush" Value="White"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#CBD3E8"/>
      <Setter Property="Margin" Value="0,7,0,7"/>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="Background" Value="#151C31"/>
      <Setter Property="Foreground" Value="#111827"/>
      <Setter Property="BorderBrush" Value="#2A3557"/>
      <Setter Property="Padding" Value="9,6"/>
    </Style>
  </Window.Resources>

  <Grid Margin="28">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="24"/>
      <ColumnDefinition Width="300"/>
    </Grid.ColumnDefinitions>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Grid Grid.Row="0" Margin="0,0,0,22">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <StackPanel Grid.Column="0">
        <TextBlock Text="VIDEO DOWNLOADER" Foreground="#9E93FF" FontWeight="Bold" FontSize="12"/>
        <TextBlock Text="Za Informer od srca &lt;3 Endrju Bejbi" FontWeight="Bold" FontSize="28" Margin="0,5,0,4"/>
        <TextBlock Text="YouTube, X/Twitter, Instagram i drugi sajtovi koje podržava yt-dlp." Foreground="#9DA8C5" FontSize="14"/>
      </StackPanel>
      <StackPanel Grid.Column="1" HorizontalAlignment="Right">
        <TextBlock x:Name="VersionText" HorizontalAlignment="Right" Foreground="#7783A5" Margin="0,0,8,7"/>
        <Button x:Name="UpdateButton" Content="Proveri ažuriranje" Background="#263250" Margin="0" Padding="12,7" FontSize="12"/>
      </StackPanel>
    </Grid>

    <Grid Grid.Row="1" Margin="0,0,0,14">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <TextBox x:Name="UrlBox" Grid.Column="0" FontSize="14" VerticalContentAlignment="Center" ToolTip="Nalepi javni URL videa"/>
      <Button x:Name="AnalyzeButton" Grid.Column="1" Content="Proveri link" Margin="10,0,0,0"/>
    </Grid>

    <Border Grid.Row="2" Background="#12192C" BorderBrush="#222D4A" BorderThickness="1" CornerRadius="8" Padding="15" Margin="0,0,0,14">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="110"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Grid.Column="0" Text="Naslov" Foreground="#7783A5" Margin="0,2,12,8"/>
        <TextBlock x:Name="TitleText" Grid.Row="0" Grid.Column="1" Text="Link još nije proveren" TextWrapping="Wrap" Margin="0,2,0,8"/>
        <TextBlock Grid.Row="1" Grid.Column="0" Text="Izvor" Foreground="#7783A5" Margin="0,0,12,8"/>
        <TextBlock x:Name="SourceText" Grid.Row="1" Grid.Column="1" Text="-" TextWrapping="Wrap" Margin="0,0,0,8"/>
        <TextBlock Grid.Row="2" Grid.Column="0" Text="Maks. kvalitet" Foreground="#7783A5" Margin="0,0,12,0"/>
        <TextBlock x:Name="QualityText" Grid.Row="2" Grid.Column="1" Text="Do 1080p"/>
      </Grid>
    </Border>

    <Grid Grid.Row="3" Margin="0,0,0,10">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <TextBox x:Name="FolderBox" Grid.Column="0" IsReadOnly="True"/>
      <Button x:Name="BrowseButton" Grid.Column="1" Content="Izaberi folder" Background="#263250" Margin="10,0,0,0"/>
    </Grid>

    <StackPanel Grid.Row="4" Margin="2,0,0,12">
      <Grid Margin="0,0,0,6">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="110"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <TextBlock Grid.Column="0" Text="Izlazni format" Foreground="#7783A5" VerticalAlignment="Center"/>
        <ComboBox x:Name="OutputFormatBox" Grid.Column="1" SelectedIndex="0">
          <ComboBoxItem Content="MP4 — H.264 + AAC (manji fajl)" Tag="mp4"/>
          <ComboBoxItem Content="MXF — DNxHR HQ + PCM (Premiere montaža)" Tag="mxf"/>
        </ComboBox>
      </Grid>
      <TextBlock x:Name="FormatHintText" Text="MP4 je preporučen za svakodnevno preuzimanje i deljenje."
                 Foreground="#9DA8C5" FontSize="12" Margin="0,0,0,5" TextWrapping="Wrap"/>
      <CheckBox x:Name="SourceCheck" Content="Dodaj izvor u metapodatke i sačuvaj .source.txt fajl" IsChecked="True"/>
      <CheckBox x:Name="PlaylistCheck" Content="Preuzmi celu plejlistu (isključeno = samo jedan video)"/>
      <TextBlock Text="Preuzimaj samo sadržaj za koji imaš dozvolu. DRM i zaštite pristupa se ne zaobilaze." Foreground="#7884A5" FontSize="12" Margin="0,5,0,0"/>
    </StackPanel>

    <Border Grid.Row="5" Background="#070B15" BorderBrush="#1D2741" BorderThickness="1" CornerRadius="6" Padding="10" Margin="0,0,0,14">
      <TextBox x:Name="LogBox" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"
               Background="Transparent" BorderThickness="0" FontFamily="Consolas" FontSize="12" Foreground="#AEB9D2"/>
    </Border>

    <Grid Grid.Row="6">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <StackPanel Grid.Column="0" VerticalAlignment="Center">
        <TextBlock x:Name="StatusText" Text="Spremno" Foreground="#9DA8C5"/>
        <ProgressBar x:Name="ProgressBar" Height="5" Margin="0,8,16,0" Minimum="0" Maximum="100" Value="0" Background="#1D2741" Foreground="#6D5DFB"/>
      </StackPanel>
      <Button x:Name="DownloadButton" Grid.Column="1" Content="Preuzmi 1080p MP4" FontSize="15" Padding="24,12"/>
      <Button x:Name="CancelButton" Grid.Column="1" Content="Otkaži" FontSize="15" Padding="24,12" Background="#B43C5A" Visibility="Collapsed"/>
    </Grid>

    <Border Grid.Column="2" Grid.Row="0" Grid.RowSpan="7" CornerRadius="16"
            BorderBrush="#6A4A3A" BorderThickness="1" Background="#15100E" ClipToBounds="True">
      <Grid>
        <Image x:Name="BossImage" Stretch="UniformToFill"/>
        <Rectangle IsHitTestVisible="False">
          <Rectangle.Fill>
            <LinearGradientBrush StartPoint="0.5,0" EndPoint="0.5,1">
              <GradientStop Color="#00000000" Offset="0.38"/>
              <GradientStop Color="#550B1020" Offset="0.68"/>
              <GradientStop Color="#EE0B1020" Offset="1"/>
            </LinearGradientBrush>
          </Rectangle.Fill>
        </Rectangle>
        <StackPanel VerticalAlignment="Bottom" Margin="22,0,22,24">
          <TextBlock Text="N A Š A" Foreground="#E8B08D" FontWeight="Bold" FontSize="12"
                     HorizontalAlignment="Center"/>
          <TextBlock Text="Šefica" Foreground="White" FontWeight="Bold" FontSize="32"
                     HorizontalAlignment="Center" Margin="0,2,0,5"/>
          <Border Height="2" Width="46" Background="#E08A5B" CornerRadius="1" HorizontalAlignment="Center"/>
        </StackPanel>
      </Grid>
    </Border>
  </Grid>
</Window>
'@

$xmlReader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

$urlBox = $window.FindName('UrlBox')
$analyzeButton = $window.FindName('AnalyzeButton')
$titleText = $window.FindName('TitleText')
$sourceText = $window.FindName('SourceText')
$qualityText = $window.FindName('QualityText')
$folderBox = $window.FindName('FolderBox')
$browseButton = $window.FindName('BrowseButton')
$sourceCheck = $window.FindName('SourceCheck')
$playlistCheck = $window.FindName('PlaylistCheck')
$logBox = $window.FindName('LogBox')
$statusText = $window.FindName('StatusText')
$progressBar = $window.FindName('ProgressBar')
$downloadButton = $window.FindName('DownloadButton')
$cancelButton = $window.FindName('CancelButton')
$versionText = $window.FindName('VersionText')
$updateButton = $window.FindName('UpdateButton')
$bossImage = $window.FindName('BossImage')
$outputFormatBox = $window.FindName('OutputFormatBox')
$formatHintText = $window.FindName('FormatHintText')

$defaultDownloads = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads\Video Downloader'
$folderBox.Text = $defaultDownloads
$versionText.Text = "Verzija $script:AppVersion"
$bossImagePath = Join-Path $script:Root 'assets\nasa-sefica.png'
if (Test-Path -LiteralPath $bossImagePath) {
    $bossBitmap = New-Object Windows.Media.Imaging.BitmapImage
    $bossBitmap.BeginInit()
    $bossBitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bossBitmap.UriSource = New-Object Uri($bossImagePath, [UriKind]::Absolute)
    $bossBitmap.EndInit()
    $bossBitmap.Freeze()
    $bossImage.Source = $bossBitmap
}

function Add-Log {
    param([string]$Message)
    $window.Dispatcher.Invoke([action]{
        $logBox.AppendText("$Message`r`n")
        $logBox.ScrollToEnd()
    })
}

function Write-CrashLog {
    param([string]$Message)
    try {
        $entry = "[{0}] {1}`r`n" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
        [IO.File]::AppendAllText($script:CrashLog, $entry, [Text.Encoding]::UTF8)
    }
    catch {}
}

function Set-Busy {
    param([bool]$Busy, [string]$Message)
    $window.Dispatcher.Invoke([action]{
        $urlBox.IsEnabled = -not $Busy
        $analyzeButton.IsEnabled = -not $Busy
        $browseButton.IsEnabled = -not $Busy
        $updateButton.IsEnabled = -not $Busy
        $outputFormatBox.IsEnabled = -not $Busy
        $downloadButton.Visibility = if ($Busy) { 'Collapsed' } else { 'Visible' }
        $cancelButton.Visibility = if ($Busy) { 'Visible' } else { 'Collapsed' }
        $cancelButton.IsEnabled = $Busy
        $statusText.Text = $Message
        if (-not $Busy) { $progressBar.IsIndeterminate = $false }
    })
}

function Test-VideoUrl {
    param([string]$Value)
    $uri = $null
    return [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -and $uri.Scheme -in @('http', 'https')
}

function ConvertTo-CommandLineArgument {
    param([AllowEmptyString()][string]$Value)
    if ($Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Invoke-UiEvents {
    $frame = New-Object Windows.Threading.DispatcherFrame
    [Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
        [Windows.Threading.DispatcherPriority]::Background,
        [Windows.Threading.DispatcherOperationCallback]{ param($f) $f.Continue = $false; return $null },
        $frame
    ) | Out-Null
    [Windows.Threading.Dispatcher]::PushFrame($frame)
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Ensure-YtDlp {
    if (Test-Path -LiteralPath $script:YtDlp) { return }
    Ensure-Directory $script:ToolsDir
    $statusText.Text = 'Preuzimam yt-dlp (samo prvi put)...'
    Add-Log 'Podešavanje: preuzimam yt-dlp sa zvaničnog GitHub izdanja.'
    Invoke-UiEvents
    (New-Object Net.WebClient).DownloadFile(
        'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe',
        $script:YtDlp
    )
}

function Ensure-Ffmpeg {
    if (Test-Path -LiteralPath $script:Ffmpeg) { return }
    Ensure-Directory $script:ToolsDir
    $zipPath = Join-Path $script:ToolsDir 'ffmpeg.zip'
    $extractPath = Join-Path $script:ToolsDir 'ffmpeg-extract'

    $statusText.Text = 'Preuzimam FFmpeg (samo prvi put, može potrajati)...'
    Add-Log 'Podešavanje: preuzimam FFmpeg essentials paket.'
    Invoke-UiEvents
    (New-Object Net.WebClient).DownloadFile(
        'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip',
        $zipPath
    )

    if (Test-Path -LiteralPath $extractPath) { Remove-Item -LiteralPath $extractPath -Recurse -Force }
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force
    $bin = Get-ChildItem -LiteralPath $extractPath -Directory | Select-Object -First 1 | ForEach-Object { Join-Path $_.FullName 'bin' }
    if (-not $bin -or -not (Test-Path -LiteralPath (Join-Path $bin 'ffmpeg.exe'))) {
        throw 'FFmpeg paket nema očekivanu strukturu.'
    }

    Ensure-Directory $script:FfmpegDir
    Copy-Item -LiteralPath (Join-Path $bin 'ffmpeg.exe') -Destination $script:Ffmpeg -Force
    Copy-Item -LiteralPath (Join-Path $bin 'ffprobe.exe') -Destination (Join-Path $script:FfmpegDir 'ffprobe.exe') -Force
    Remove-Item -LiteralPath $zipPath -Force
    Remove-Item -LiteralPath $extractPath -Recurse -Force
}

function Get-LatestRelease {
    $client = New-Object Net.WebClient
    $client.Headers.Add('User-Agent', 'Informer-Video-Downloader')
    $client.Headers.Add('Accept', 'application/vnd.github+json')
    $json = $client.DownloadString("https://api.github.com/repos/$script:GitHubRepo/releases/latest")
    return $json | ConvertFrom-Json
}

function Start-AppUpdate {
    param($Release)

    $zipAsset = @($Release.assets | Where-Object { $_.name -eq 'Video-Downloader-Update.zip' }) | Select-Object -First 1
    $hashAsset = @($Release.assets | Where-Object { $_.name -eq 'Video-Downloader-Update.zip.sha256' }) | Select-Object -First 1
    if (-not $zipAsset -or -not $hashAsset) {
        throw 'Release nema update ZIP ili SHA-256 fajl.'
    }

    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ('InformerVideoDownloader-' + [guid]::NewGuid().ToString('N'))
    Ensure-Directory $tempDir
    $zipPath = Join-Path $tempDir 'update.zip'
    $hashPath = Join-Path $tempDir 'update.sha256'
    $client = New-Object Net.WebClient
    $client.Headers.Add('User-Agent', 'Informer-Video-Downloader')
    $client.DownloadFile([string]$zipAsset.browser_download_url, $zipPath)
    $client.DownloadFile([string]$hashAsset.browser_download_url, $hashPath)

    $expectedHash = ((Get-Content -LiteralPath $hashPath -Raw).Trim() -split '\s+')[0]
    $actualHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
        throw 'SHA-256 provera update paketa nije uspela.'
    }

    $updater = Join-Path $script:Root 'Apply-Update.ps1'
    if (-not (Test-Path -LiteralPath $updater)) {
        throw 'Apply-Update.ps1 nije pronađen.'
    }

    $arguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
        '-File', $updater,
        '-InstallDirectory', $script:Root,
        '-ZipPath', $zipPath,
        '-ParentProcessId', $PID
    )
    $argumentLine = ($arguments | ForEach-Object { ConvertTo-CommandLineArgument ([string]$_) }) -join ' '
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argumentLine -WindowStyle Hidden
    $window.Close()
}

function Check-ForUpdate {
    param([bool]$Silent = $false)

    try {
        $updateButton.IsEnabled = $false
        $updateButton.Content = 'Proveravam...'
        $release = Get-LatestRelease
        $latestText = ([string]$release.tag_name).TrimStart('v', 'V')
        $currentVersion = New-Object Version $script:AppVersion
        $latestVersion = New-Object Version $latestText

        if ($latestVersion -le $currentVersion) {
            if (-not $Silent) {
                [Windows.MessageBox]::Show("Već koristiš najnoviju verziju ($script:AppVersion).", 'Ažuriranje', 'OK', 'Information') | Out-Null
            }
            return
        }

        $answer = [Windows.MessageBox]::Show(
            "Dostupna je verzija $latestText. Želiš li da je preuzmem i instaliram sada?",
            'Dostupno ažuriranje', 'YesNo', 'Question'
        )
        if ($answer -eq [Windows.MessageBoxResult]::Yes) {
            Set-Busy $true "Preuzimam ažuriranje $latestText..."
            Start-AppUpdate $release
        }
    }
    catch {
        Write-CrashLog "Update check: $($_.Exception)"
        if (-not $Silent) {
            [Windows.MessageBox]::Show('Provera ažuriranja trenutno nije uspela. Pokušaj ponovo kasnije.', 'Ažuriranje', 'OK', 'Warning') | Out-Null
        }
    }
    finally {
        $updateButton.IsEnabled = $true
        $updateButton.Content = 'Proveri ažuriranje'
    }
}

function Invoke-YtDlpSync {
    param([string[]]$Arguments)
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $script:YtDlp
    $psi.Arguments = (($Arguments | ForEach-Object { ConvertTo-CommandLineArgument $_ }) -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw ($stderr.Trim() | Select-Object -First 1) }
    return $stdout
}

function Update-DownloadLine {
    param([string]$Line)
    if ([string]::IsNullOrWhiteSpace($Line)) { return }

    $logBox.AppendText("$Line`r`n")
    $logBox.ScrollToEnd()
    if ($Line -match '\[download\]\s+(\d+(?:\.\d+)?)%') {
        $progressBar.IsIndeterminate = $false
        $progressBar.Value = [double]$matches[1]
        $statusText.Text = "Preuzimanje: $($matches[1])%"
    }
    elseif ($Line -match '^\[Merger\]|^\[Metadata\]|^\[Embed') {
        $progressBar.IsIndeterminate = $true
        $statusText.Text = 'Spajam tokove i upisujem metapodatke...'
    }
    elseif ($Line -match '^\[MXF\]') {
        $progressBar.IsIndeterminate = $true
        $statusText.Text = 'Pravim MXF za montažu...'
    }
    elseif ($Line -match '^ERROR:') {
        $statusText.Text = 'Greška pri preuzimanju; pokušavam ponovo...'
    }
}

function Stop-ProcessMonitor {
    if ($script:ProcessTimer) {
        $script:ProcessTimer.Stop()
        $script:ProcessTimer = $null
    }
    $script:OutputReadTask = $null
    $script:ErrorReadTask = $null
}

function Complete-DownloadProcess {
    param([int]$ExitCode)

    Stop-ProcessMonitor
    $process = $script:CurrentProcess
    $script:CurrentProcess = $null
    if ($process) { $process.Dispose() }
    $progressBar.IsIndeterminate = $false

    $completedStage = $script:CurrentStage
    $script:CurrentStage = 'idle'

    if ($script:CancelRequested) {
        $script:CancelRequested = $false
        Set-Busy $false 'Otkazano; delimični fajl je sačuvan za nastavak'
        Add-Log 'Preuzimanje je zaustavljeno. Sledeći klik na isti link nastavlja .part fajl.'
    }
    elseif ($ExitCode -eq 0) {
        if ($completedStage -eq 'download' -and $script:OutputMode -eq 'mxf') {
            Start-MxfConversion
            return
        }
        $progressBar.Value = 100
        Set-Busy $false 'Završeno; aplikacija je spremna za sledeći link'
        $formatLabel = if ($completedStage -eq 'mxf') { 'MXF' } else { 'MP4' }
        Add-Log "Gotovo ($formatLabel). Fajlovi su sačuvani u: $($folderBox.Text)"
        [System.Media.SystemSounds]::Asterisk.Play()
    }
    else {
        Set-Busy $false "Preuzimanje je prekinuto (kod $ExitCode)"
        if ($completedStage -eq 'mxf') {
            Add-Log 'MXF konverzija nije uspela. Privremeni MP4 je sačuvan i možeš ga koristiti.'
        }
        else {
            Add-Log 'Delimični .part fajl je sačuvan. Ponovi isti link da se preuzimanje nastavi.'
        }
    }
}

function Read-CompletedOutput {
    param(
        [ValidateSet('Output', 'Error')][string]$Stream,
        [int]$MaximumLines = 200
    )

    for ($i = 0; $i -lt $MaximumLines; $i++) {
        $task = if ($Stream -eq 'Output') { $script:OutputReadTask } else { $script:ErrorReadTask }
        if (-not $task -or -not $task.IsCompleted) { break }

        $line = $task.Result
        if ($null -eq $line) {
            if ($Stream -eq 'Output') { $script:OutputReadTask = $null } else { $script:ErrorReadTask = $null }
            break
        }

        Update-DownloadLine $line
        if ($Stream -eq 'Output') {
            $script:OutputReadTask = $script:CurrentProcess.StandardOutput.ReadLineAsync()
        }
        else {
            $script:ErrorReadTask = $script:CurrentProcess.StandardError.ReadLineAsync()
        }
    }
}

function Start-YtDlpProcess {
    param(
        [string[]]$Arguments,
        [string]$FileName = $script:YtDlp
    )

    if ($script:CurrentProcess -and -not $script:CurrentProcess.HasExited) {
        throw 'Jedno preuzimanje je već u toku.'
    }

    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $FileName
    $psi.Arguments = (($Arguments | ForEach-Object { ConvertTo-CommandLineArgument $_ }) -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8

    $script:CancelRequested = $false
    $script:CurrentProcess = New-Object Diagnostics.Process
    $script:CurrentProcess.StartInfo = $psi
    [void]$script:CurrentProcess.Start()
    $script:OutputReadTask = $script:CurrentProcess.StandardOutput.ReadLineAsync()
    $script:ErrorReadTask = $script:CurrentProcess.StandardError.ReadLineAsync()

    $script:ProcessTimer = New-Object Windows.Threading.DispatcherTimer
    $script:ProcessTimer.Interval = [TimeSpan]::FromMilliseconds(100)
    $script:ProcessTimer.Add_Tick({
        try {
            Read-CompletedOutput -Stream Output
            Read-CompletedOutput -Stream Error

            if ($script:CurrentProcess -and $script:CurrentProcess.HasExited -and
                -not $script:OutputReadTask -and -not $script:ErrorReadTask) {
                Complete-DownloadProcess $script:CurrentProcess.ExitCode
            }
        }
        catch {
            $message = $_.Exception.ToString()
            Write-CrashLog $message
            Add-Log "Interna greška: $($_.Exception.Message)"
            if ($script:CurrentProcess -and -not $script:CurrentProcess.HasExited) {
                try { $script:CurrentProcess.Kill() } catch {}
            }
            Complete-DownloadProcess 1
        }
    })
    $script:ProcessTimer.Start()
}

function Start-MxfConversion {
    $converter = Join-Path $script:Root 'Convert-ToMxf.ps1'
    if (-not (Test-Path -LiteralPath $converter)) {
        throw 'Convert-ToMxf.ps1 nije pronađen.'
    }

    $script:CurrentStage = 'mxf'
    Set-Busy $true 'Pravim MXF za montažu...'
    $progressBar.IsIndeterminate = $true
    Add-Log 'Preuzimanje je završeno. Konvertujem MP4 u DNxHR HQ / PCM MXF...'
    $arguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $converter,
        '-ManifestPath', $script:DownloadManifest,
        '-FfmpegPath', $script:Ffmpeg
    )
    Start-YtDlpProcess -Arguments $arguments -FileName 'powershell.exe'
}

function Analyze-Url {
    $url = $urlBox.Text.Trim()
    if (-not (Test-VideoUrl $url)) {
        [Windows.MessageBox]::Show('Unesi ispravan http/https link.', 'Neispravan link', 'OK', 'Warning') | Out-Null
        return
    }

    try {
        Set-Busy $true 'Proveravam link...'
        $progressBar.IsIndeterminate = $true
        Ensure-YtDlp
        $json = Invoke-YtDlpSync @('--dump-single-json', '--no-playlist', '--no-warnings', '--', $url)
        $info = $json | ConvertFrom-Json
        $script:LastInfo = $info
        $titleText.Text = if ($info.title) { [string]$info.title } else { 'Bez naslova' }
        $sourceText.Text = if ($info.webpage_url_domain) { [string]$info.webpage_url_domain } elseif ($info.extractor_key) { [string]$info.extractor_key } else { ([uri]$url).Host }
        $heights = @($info.formats | Where-Object { $_.height } | ForEach-Object { [int]$_.height })
        $maxHeight = if ($heights.Count) { ($heights | Measure-Object -Maximum).Maximum } else { $null }
        $qualityText.Text = if ($maxHeight) { "Dostupno do ${maxHeight}p; preuzimanje ograničeno na 1080p" } else { 'Najbolji dostupni kvalitet, do 1080p' }
        Add-Log "Link je podržan: $($titleText.Text)"
        Set-Busy $false 'Link je spreman za preuzimanje'
    }
    catch {
        Set-Busy $false 'Link nije moguće obraditi'
        Add-Log "Greška: $($_.Exception.Message)"
        [Windows.MessageBox]::Show('Video nije pronađen, nije javan ili sajt trenutno nije podržan.', 'Provera nije uspela', 'OK', 'Warning') | Out-Null
    }
}

$browseButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Izaberi folder za preuzete videe'
    $dialog.SelectedPath = $folderBox.Text
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $folderBox.Text = $dialog.SelectedPath
    }
})

$analyzeButton.Add_Click({ Analyze-Url })
$urlBox.Add_KeyDown({ if ($_.Key -eq 'Enter') { Analyze-Url } })
$updateButton.Add_Click({ Check-ForUpdate $false })
$outputFormatBox.Add_SelectionChanged({
    $selectedTag = [string]$outputFormatBox.SelectedItem.Tag
    if ($selectedTag -eq 'mxf') {
        $formatHintText.Text = 'MXF koristi DNxHR HQ i PCM audio za Premiere. Fajl može biti 20–50 puta veći od MP4-a.'
        $downloadButton.Content = 'Preuzmi i napravi MXF'
    }
    else {
        $formatHintText.Text = 'MP4 je preporučen za svakodnevno preuzimanje i deljenje.'
        $downloadButton.Content = 'Preuzmi 1080p MP4'
    }
})

$downloadButton.Add_Click({
    $url = $urlBox.Text.Trim()
    if (-not (Test-VideoUrl $url)) {
        [Windows.MessageBox]::Show('Unesi ispravan http/https link.', 'Neispravan link', 'OK', 'Warning') | Out-Null
        return
    }

    try {
        Set-Busy $true 'Pripremam preuzimanje...'
        $progressBar.Value = 0
        $logBox.Clear()
        Ensure-YtDlp
        Ensure-Ffmpeg
        Ensure-Directory $folderBox.Text

        $script:OutputMode = [string]$outputFormatBox.SelectedItem.Tag
        $script:CurrentStage = 'download'
        $script:DownloadManifest = $null

        $outputTemplate = Join-Path $folderBox.Text '%(title).180B [%(id)s].%(ext)s'
        $args = @(
            '--newline',
            '--progress',
            '--continue',
            '--part',
            '--retries', '10',
            '--fragment-retries', '10',
            '--retry-sleep', '2',
            '--socket-timeout', '30',
            '--ffmpeg-location', $script:FfmpegDir,
            '--format', 'bestvideo[height<=1080][vcodec^=avc1]+bestaudio[acodec^=mp4a.40.2]/bestvideo[height<=1080][vcodec^=avc1]+bestaudio[ext=m4a]/best[height<=1080][vcodec^=avc1][acodec^=mp4a.40.2]/best/bestvideo[height<=1080]+bestaudio/best',
            '--merge-output-format', 'mp4',
            '--embed-metadata',
            '--postprocessor-args', 'Metadata+ffmpeg_o:-c:v copy -c:a aac -profile:a aac_low -ar 48000 -b:a 192k',
            '--windows-filenames',
            '--trim-filenames', '200',
            '--output', $outputTemplate
        )

        if (-not $playlistCheck.IsChecked) { $args += '--no-playlist' }
        if ($script:OutputMode -eq 'mxf') {
            $script:DownloadManifest = Join-Path ([IO.Path]::GetTempPath()) ('InformerVideoDownloader-' + [guid]::NewGuid().ToString('N') + '.paths.txt')
            $args += @('--print-to-file', 'after_move:%(filepath)s', $script:DownloadManifest)
        }
        if ($sourceCheck.IsChecked) {
            $args += @(
                '--parse-metadata', 'webpage_url:(?P<meta_comment>.+)',
                '--write-info-json',
                '--write-description',
                '--print-to-file', 'after_move:Source: %(webpage_url)s', "$outputTemplate.source.txt"
            )
        }

        $args += @('--', $url)
        $formatName = if ($script:OutputMode -eq 'mxf') { 'MXF (posle MP4 preuzimanja)' } else { 'MP4' }
        Add-Log "Pokrećem preuzimanje do 1080p. Izlaz: $formatName."
        Start-YtDlpProcess $args
    }
    catch {
        Set-Busy $false 'Podešavanje nije uspelo'
        Add-Log "Greška: $($_.Exception.Message)"
        [Windows.MessageBox]::Show('Nije moguće pripremiti alate. Proveri internet vezu i pokušaj ponovo.', 'Greška pri podešavanju', 'OK', 'Error') | Out-Null
    }
})

$cancelButton.Add_Click({
    if ($script:CurrentProcess -and -not $script:CurrentProcess.HasExited) {
        $script:CancelRequested = $true
        $statusText.Text = 'Zaustavljam preuzimanje...'
        $cancelButton.IsEnabled = $false
        try { $script:CurrentProcess.Kill() } catch {}
    }
})

$window.Add_Closing({
    Stop-ProcessMonitor
    if ($script:CurrentProcess -and -not $script:CurrentProcess.HasExited) {
        try { $script:CurrentProcess.Kill() } catch {}
    }
})

$window.Dispatcher.Add_UnhandledException({
    param($sender, $eventArgs)
    Write-CrashLog $eventArgs.Exception.ToString()
    try {
        $logBox.AppendText("Interna greška je zabeležena. Aplikacija ostaje otvorena.`r`n")
        $logBox.ScrollToEnd()
        $statusText.Text = 'Greška je zabeležena; možeš pokušati ponovo'
        Set-Busy $false $statusText.Text
    }
    catch {}
    $eventArgs.Handled = $true
})

$window.Add_ContentRendered({
    if (-not $script:UpdateChecked) {
        $script:UpdateChecked = $true
        Check-ForUpdate $true
    }
})

Add-Log 'Nalepi javni link, proveri ga, pa klikni "Preuzmi 1080p".'
if ($env:DOWNLOADER_SMOKE_TEST -eq '1') {
    Set-Busy $true 'Testiram download proces...'
    Start-YtDlpProcess @('--version')
    $deadline = (Get-Date).AddSeconds(10)
    while ($script:CurrentProcess -and (Get-Date) -lt $deadline) {
        Invoke-UiEvents
        Start-Sleep -Milliseconds 50
    }
    if ($script:CurrentProcess) {
        try { $script:CurrentProcess.Kill() } catch {}
        throw 'Download process monitor test je istekao.'
    }
    Write-Output 'Download process monitor: OK'
}
else {
    [void]$window.ShowDialog()
}
