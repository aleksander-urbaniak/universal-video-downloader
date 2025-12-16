#requires -Version 5.1
# Universal Video Downloader
# - Modern WPF UI
# - Dark/Light theme toggle
# - Integrated Color Log with Copy/Clear support
# - Status Bar with Progress, Speed, and Size
# - Engine: yt-dlp (Auto-install/Auto-remove) + TikWM/Cobalt APIs

# ---------------------------------------------------------
# NETWORK SECURITY FIXES
# ---------------------------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http

# ---------------------------------------------------------
# XAML
# ---------------------------------------------------------
$version = "v1.0.0"

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Universal Video Downloader" Height="620" Width="700" 
        WindowStartupLocation="CenterScreen"
        Background="{DynamicResource BgBrush}"
        FontFamily="Segoe UI">

    <Window.Resources>
        <!-- THEME RESOURCES -->
        <SolidColorBrush x:Key="BgBrush">#F3F4F6</SolidColorBrush>
        <SolidColorBrush x:Key="CardBrush">#FFFFFF</SolidColorBrush>
        <SolidColorBrush x:Key="TextBrush">#1F2937</SolidColorBrush>
        <SolidColorBrush x:Key="SubTextBrush">#6B7280</SolidColorBrush>
        <SolidColorBrush x:Key="BorderBrush">#E5E7EB</SolidColorBrush>
        <SolidColorBrush x:Key="InputBgBrush">#FFFFFF</SolidColorBrush>
        <SolidColorBrush x:Key="PrimaryBrush">#4F46E5</SolidColorBrush>

        <!-- INPUT STYLE -->
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="Background" Value="{DynamicResource InputBgBrush}"/>
            <Setter Property="Foreground" Value="{DynamicResource TextBrush}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource BorderBrush}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" 
                                CornerRadius="6">
                            <ScrollViewer x:Name="PART_ContentHost"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- BUTTON STYLE -->
        <Style TargetType="Button">
            <Setter Property="Background" Value="{DynamicResource PrimaryBrush}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Padding" Value="15,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Opacity" Value="0.9"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.6"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- SECONDARY BUTTON STYLE -->
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{DynamicResource TextBrush}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{DynamicResource BorderBrush}"/>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- NAVBAR -->
        <Border Grid.Row="0" Background="{DynamicResource CardBrush}" Padding="20,15" 
                BorderThickness="0,0,0,1" BorderBrush="{DynamicResource BorderBrush}">
            <Grid>
                <StackPanel Orientation="Horizontal">
                    <Border Background="{DynamicResource PrimaryBrush}" CornerRadius="6" Width="30" Height="30" Margin="0,0,10,0">
                        <TextBlock Text="V" Foreground="White" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <TextBlock Text="Universal Downloader" FontWeight="Bold" FontSize="18" 
                               Foreground="{DynamicResource TextBrush}" VerticalAlignment="Center"/>
                </StackPanel>
                <Button Name="ThemeToggleBtn" Content="Dark Mode" HorizontalAlignment="Right" 
                        Style="{StaticResource SecondaryButton}" FontSize="12"/>
            </Grid>
        </Border>

        <!-- MAIN CONTENT -->
        <StackPanel Grid.Row="1" Margin="30,30,30,10">
            
            <TextBlock Text="Paste Link (TikTok, YouTube, Insta, Facebook or Direct URL)" 
                       Foreground="{DynamicResource SubTextBrush}" Margin="0,0,0,8" FontWeight="SemiBold"/>
            <TextBox Name="InputUrl" FontSize="14" Height="40"/>

            <TextBlock Text="Save Location" Foreground="{DynamicResource SubTextBrush}" 
                       Margin="0,20,0,8" FontWeight="SemiBold"/>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="10"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBox Grid.Column="0" Name="InputPath" IsReadOnly="True" FontSize="14" Height="40"/>
                <Button Grid.Column="2" Name="BtnBrowse" Content="Browse..." Style="{StaticResource SecondaryButton}" Height="40"/>
            </Grid>

            <Button Name="BtnDownload" Content="Download Video" FontSize="16" FontWeight="Bold" Margin="0,30,0,0" Height="50"/>

        </StackPanel>

        <!-- LOG AREA -->
        <Border Grid.Row="2" Margin="30,10,30,30" Background="{DynamicResource CardBrush}" 
                BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="6">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                
                <Border BorderBrush="{DynamicResource BorderBrush}" BorderThickness="0,0,0,1" Padding="10,5" Background="{DynamicResource BgBrush}">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="10"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        
                        <TextBlock Text="Activity Log" FontSize="12" FontWeight="SemiBold" 
                                   Foreground="{DynamicResource SubTextBrush}" VerticalAlignment="Center"/>
                        
                        <Button Grid.Column="1" Name="BtnCopyLog" Content="Copy" Style="{StaticResource SecondaryButton}" FontSize="12" Padding="10,4"/>
                        <Button Grid.Column="3" Name="BtnClearLog" Content="Clear" Style="{StaticResource SecondaryButton}" FontSize="12" Padding="10,4"/>
                    </Grid>
                </Border>
                
                <ScrollViewer Grid.Row="1" Name="LogScroll" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" Padding="5">
                    <StackPanel Name="LogPanel" Orientation="Vertical"/>
                </ScrollViewer>
            </Grid>
        </Border>

        <!-- STATUS BAR -->
        <Border Grid.Row="3" Padding="15" Background="{DynamicResource CardBrush}" 
                BorderThickness="0,1,0,0" BorderBrush="{DynamicResource BorderBrush}">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" Orientation="Vertical" VerticalAlignment="Center" Margin="0,0,20,0">
                    <Grid Margin="0,0,0,5">
                         <TextBlock Name="TxtStatus" Text="Ready" Foreground="{DynamicResource SubTextBrush}" FontSize="13" HorizontalAlignment="Left"/>
                         <TextBlock Name="TxtProgressDetails" Text="" Foreground="{DynamicResource SubTextBrush}" FontSize="12" HorizontalAlignment="Right"/>
                    </Grid>
                    <ProgressBar Name="PrgBar" Height="8" BorderThickness="0" Background="{DynamicResource BgBrush}" Foreground="{DynamicResource PrimaryBrush}" Minimum="0" Maximum="100"/>
                </StackPanel>

                <TextBlock Grid.Column="1" Text="$version" Foreground="{DynamicResource SubTextBrush}" FontSize="13" VerticalAlignment="Bottom" Opacity="0.5"/>
            </Grid>
        </Border>

    </Grid>
</Window>
"@

# ---------------------------------------------------------
# Parse XAML
# ---------------------------------------------------------
$reader = New-Object System.Xml.XmlNodeReader $xaml
try {
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Error "Error parsing XAML: $($_.Exception.Message)"
    exit
}

# ---------------------------------------------------------
# Find controls
# ---------------------------------------------------------
$btnTheme    = $window.FindName("ThemeToggleBtn")
$inputUrl    = $window.FindName("InputUrl")
$inputPath   = $window.FindName("InputPath")
$btnBrowse   = $window.FindName("BtnBrowse")
$btnDownload = $window.FindName("BtnDownload")
$txtStatus   = $window.FindName("TxtStatus")
$txtProgress = $window.FindName("TxtProgressDetails")
$prgBar      = $window.FindName("PrgBar")

$logPanel    = $window.FindName("LogPanel")
$logScroll   = $window.FindName("LogScroll")
$btnCopyLog  = $window.FindName("BtnCopyLog")
$btnClearLog = $window.FindName("BtnClearLog")

# Default save path
$inputPath.Text = [Environment]::GetFolderPath("Desktop")

# ---------------------------------------------------------
# Helpers
# ---------------------------------------------------------
function Get-Brush ([string]$hex) {
    return [Windows.Media.BrushConverter]::new().ConvertFrom($hex)
}

$global:LogBuffer = New-Object System.Text.StringBuilder

function Add-Log ([string]$msg) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    $fullMsg = "[$timestamp] $msg"
    
    # Store plain text in buffer for Copy button
    $null = $global:LogBuffer.AppendLine($fullMsg)
    
    # Create visual element for LogPanel
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $fullMsg
    $tb.FontFamily = "Consolas"
    $tb.FontSize = 12
    $tb.TextWrapping = "Wrap"
    $tb.Margin = "0,0,0,2"
    
    # Color Logic
    if ($msg -match "(?i)(error|failed|exception)") {
        $tb.Foreground = [Windows.Media.Brushes]::IndianRed
        $tb.FontWeight = "Bold"
    }
    elseif ($msg -match "(?i)(success|complete|ready|resolved|finished)") {
        $tb.Foreground = [Windows.Media.Brushes]::SeaGreen
        $tb.FontWeight = "Bold"
    }
    elseif ($msg -match "(?i)(warning|unknown|check)") {
        $tb.Foreground = [Windows.Media.Brushes]::DarkOrange
    }
    else {
        # Adaptive color (TextBrush)
        $tb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "TextBrush")
    }
    
    $logPanel.Children.Add($tb) | Out-Null
    $logScroll.ScrollToBottom()
}

function Clean-FileName ([string]$name) {
    return $name -replace '[\\/:*?"<>|]', ''
}

function Show-Err([string]$text, [string]$caption = "Error") {
    [System.Windows.Forms.MessageBox]::Show(
        $text,
        $caption,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Show-Info([string]$text, [string]$caption = "Info") {
    [System.Windows.Forms.MessageBox]::Show(
        $text,
        $caption,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Format-Size ([double]$Bytes) {
    if ($Bytes -lt 1KB) { return "{0:N2} B" -f $Bytes }
    if ($Bytes -lt 1MB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    if ($Bytes -lt 1GB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    return "{0:N2} GB" -f ($Bytes / 1GB)
}

function Remove-InvisibleChars([string]$s) {
    if ($null -eq $s) { return $s }
    $s = $s -replace "[\u200B\u200C\u200D\u2060\uFEFF]", ""
    $s = $s -replace "[\u00A0]", " "
    return $s
}

function Normalize-Url([string]$raw) {
    $raw = Remove-InvisibleChars $raw
    $raw = $raw.Trim()

    if ($raw -match '^(www\.)' ) { $raw = "https://$raw" }
    elseif ($raw -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://' ) {
        $raw = "https://$raw"
    }

    $uri = $null
    if (-not [System.Uri]::TryCreate($raw, [System.UriKind]::Absolute, [ref]$uri)) {
        throw "Invalid URL format." 
    }
    return $uri
}

# ---------------------------------------------------------
# TEMP TOOL MANAGEMENT (Auto-Install/Uninstall)
# ---------------------------------------------------------
# Create a unique temp directory for this session
$global:TempToolDir = Join-Path $env:TEMP ("UVD_" + [Guid]::NewGuid().ToString().Substring(0, 8))

function Install-YtDlp {
    if (-not (Test-Path $global:TempToolDir)) {
        New-Item -Path $global:TempToolDir -ItemType Directory -Force | Out-Null
    }
    
    $exePath = Join-Path $global:TempToolDir "yt-dlp.exe"
    
    if (-not (Test-Path $exePath)) {
        Add-Log "Downloading engine (yt-dlp)..."
        [System.Windows.Forms.Application]::DoEvents()
        
        try {
            # Download engine with progress too
            Download-File-WithProgress -Url "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" -Path $exePath -LogName "Engine"
            Add-Log "Engine ready."
        } catch {
            throw "Failed to download yt-dlp: $($_.Exception.Message)"
        }
    }
    return $exePath
}

function Cleanup-Environment {
    # This runs when script closes
    if (Test-Path $global:TempToolDir) {
        try {
            Remove-Item -Path $global:TempToolDir -Recurse -Force -ErrorAction SilentlyContinue
        } catch {}
    }
}

# ---------------------------------------------------------
# Download Functions
# ---------------------------------------------------------

function Download-File-WithProgress {
    param(
        [string]$Url,
        [string]$Path,
        [hashtable]$Headers = $null,
        [string]$LogName = "File"
    )

    $httpClient = New-Object System.Net.Http.HttpClient
    if ($Headers) {
        foreach ($key in $Headers.Keys) {
            if ($key -eq "User-Agent") {
                $httpClient.DefaultRequestHeaders.UserAgent.ParseAdd($Headers[$key])
            } else {
                $httpClient.DefaultRequestHeaders.TryAddWithoutValidation($key, $Headers[$key]) | Out-Null
            }
        }
    }

    try {
        $response = $httpClient.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
        if (-not $response.IsSuccessStatusCode) {
            throw "HTTP Error: $($response.StatusCode)"
        }

        $totalBytes = $response.Content.Headers.ContentLength
        if ($null -eq $totalBytes) { $totalBytes = -1 }
        
        $remoteStream = $response.Content.ReadAsStreamAsync().Result
        $fileStream = [System.IO.File]::Create($Path)
        
        $buffer = New-Object byte[] 65536 # 64KB buffer
        $totalRead = 0
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $lastUpdate = 0
        
        # Reset UI
        $prgBar.Value = 0
        $prgBar.IsIndeterminate = if ($totalBytes -eq -1) { $true } else { $false }
        
        do {
            $readCount = $remoteStream.Read($buffer, 0, $buffer.Length)
            if ($readCount -gt 0) {
                $fileStream.Write($buffer, 0, $readCount)
                $totalRead += $readCount
                
                # Update UI every 100ms
                if ($sw.ElapsedMilliseconds -gt $lastUpdate + 100) {
                    $speed = 0
                    if ($sw.Elapsed.TotalSeconds -gt 0) {
                        $speed = $totalRead / $sw.Elapsed.TotalSeconds
                    }
                    
                    if ($totalBytes -gt 0) {
                        $percent = ($totalRead / $totalBytes) * 100
                        $prgBar.Value = $percent
                        $txtStatus.Text = "Downloading $LogName... {0:N0}%" -f $percent
                        $txtProgress.Text = "{0} of {1} @ {2}/s" -f (Format-Size $totalRead), (Format-Size $totalBytes), (Format-Size $speed)
                    } else {
                        $txtStatus.Text = "Downloading $LogName..."
                        $txtProgress.Text = "{0} @ {1}/s" -f (Format-Size $totalRead), (Format-Size $speed)
                    }
                    
                    [System.Windows.Forms.Application]::DoEvents()
                    $lastUpdate = $sw.ElapsedMilliseconds
                }
            }
        } while ($readCount -gt 0)
        
        $prgBar.Value = 100
        $txtStatus.Text = "Complete"
        $txtProgress.Text = ""

    } finally {
        if ($fileStream) { $fileStream.Close(); $fileStream.Dispose() }
        if ($remoteStream) { $remoteStream.Close(); $remoteStream.Dispose() }
        if ($httpClient) { $httpClient.Dispose() }
    }
}

function Download-TikTok ($url) {
    Add-Log "Connecting to TikTok API..."
    [System.Windows.Forms.Application]::DoEvents()

    $apiUrl = "https://www.tikwm.com/api/"
    $payload = @{ url = $url }
    $headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }
    
    $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $payload -Headers $headers -ErrorAction Stop

    if ($response.code -eq 0) {
        Add-Log "Video found: $($response.data.title)"
        $videoUrl = $response.data.play
        $id = $response.data.id
        $author = $response.data.author.unique_id
        $fileName = "tiktok_${author}_${id}.mp4"
        return @{ url = $videoUrl; fileName = $fileName }
    }
    throw "TikTok API returned error."
}

function Download-Universal ($url) {
    # Cobalt API for Insta/Others
    Add-Log "Connecting to Universal API..."
    [System.Windows.Forms.Application]::DoEvents()
    
    $apiUrl = "https://api.cobalt.tools/api/json"
    $payload = @{
        url = $url
        vQuality = "max"
        filenamePattern = "basic"
    } | ConvertTo-Json -Compress

    $headers = @{
        "Accept" = "application/json"
        "Origin" = "https://cobalt.tools"
        "Referer" = "https://cobalt.tools/"
        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    }

    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $payload -ContentType "application/json" -Headers $headers -ErrorAction Stop

        if ($response.status -eq "stream" -or $response.status -eq "redirect") {
            Add-Log "Stream resolved."
            $fileName = "video_$(Get-Date -Format 'yyyyMMdd_HHmmss').mp4"
            if ($response.filename) { $fileName = Clean-FileName $response.filename }
            return @{ url = $response.url; fileName = $fileName }
        }
        elseif ($response.status -eq "picker") {
            if ($response.picker.Count -gt 0) {
                Add-Log "Media picker found. Selecting first item."
                $item = $response.picker[0]
                $fileName = "media_$(Get-Date -Format 'yyyyMMdd_HHmmss').mp4"
                return @{ url = $item.url; fileName = $fileName }
            }
        }
        if ($response.status -eq "error") { throw "Cobalt Error: $($response.text)" }
    }
    catch {
        throw "Universal API Error: $($_.Exception.Message)"
    }
    throw "Could not resolve stream."
}

function Download-Native-YtDlp ($url, $saveDir) {
    # 1. Setup Tool
    $exe = Install-YtDlp
    
    Add-Log "Starting download engine..."
    [System.Windows.Forms.Application]::DoEvents()
    
    $outputTemplate = Join-Path $saveDir "%(title)s.%(ext)s"
    
    $argsList = "-f best --no-mtime -o `"$outputTemplate`" `"$url`""
    
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $exe
    $pinfo.Arguments = $argsList
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    
    # Regex to parse yt-dlp progress output
    # Example: [download]  23.5% of 10.00MiB at  2.00MiB/s ETA 00:05
    $regex = '\[download\]\s+(\d+\.\d+)%\s+of\s+(?:~)?([\d\.]+\w+)\s+at\s+(?:~)?([\d\.]+\w+/s)'
    
    while (-not $p.HasExited) {
        $line = $p.StandardOutput.ReadLine()
        if ($line) { 
            # Parse progress
            if ($line -match $regex) {
                $percent = $Matches[1]
                $size = $Matches[2]
                $speed = $Matches[3]
                
                $prgBar.Value = [double]$percent
                $txtStatus.Text = "Downloading... $percent%"
                $txtProgress.Text = "$size @ $speed"
            } else {
                 Add-Log "yt: $line"
            }
        }
        [System.Windows.Forms.Application]::DoEvents()
    }
    
    if ($p.ExitCode -eq 0) {
        return $true
    } else {
        $err = $p.StandardError.ReadToEnd()
        throw "yt-dlp error: $err"
    }
}

function Download-DirectMedia([uri]$uri) {
    Add-Log "Direct URL mode..."
    $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    $headers = @{ "User-Agent" = $ua }
    
    $suggestedName = $null
    try {
        $head = Invoke-WebRequest -Uri $uri.AbsoluteUri -Method Head -Headers $headers -TimeoutSec 10 -ErrorAction SilentlyContinue
        if ($head) {
             $cd = $head.Headers["Content-Disposition"]
             if ($cd -and $cd -match 'filename="?(?<fn>[^";]+)"?') { $suggestedName = $Matches.fn }
        }
    } catch {}

    $base = [System.IO.Path]::GetFileName($uri.AbsolutePath)
    if (-not $base) { $base = "download" }
    $fileName = if ($suggestedName) { Clean-FileName $suggestedName } else { Clean-FileName $base }
    if (-not [System.IO.Path]::GetExtension($fileName)) { $fileName += ".mp4" }

    return @{ url = $uri.AbsoluteUri; fileName = $fileName; headers = $headers }
}

# ---------------------------------------------------------
# Theme toggle
# ---------------------------------------------------------
$global:isDarkMode = $false

$btnTheme.Add_Click({
    $global:isDarkMode = -not $global:isDarkMode

    if ($global:isDarkMode) {
        $window.Resources["BgBrush"]      = Get-Brush "#111827"
        $window.Resources["CardBrush"]    = Get-Brush "#1F2937"
        $window.Resources["TextBrush"]    = Get-Brush "#F9FAFB"
        $window.Resources["SubTextBrush"] = Get-Brush "#9CA3AF"
        $window.Resources["BorderBrush"]  = Get-Brush "#374151"
        $window.Resources["InputBgBrush"] = Get-Brush "#374151"
        $btnTheme.Content = "Light Mode"
        Add-Log "Theme: Dark"
    } else {
        $window.Resources["BgBrush"]      = Get-Brush "#F3F4F6"
        $window.Resources["CardBrush"]    = Get-Brush "#FFFFFF"
        $window.Resources["TextBrush"]    = Get-Brush "#1F2937"
        $window.Resources["SubTextBrush"] = Get-Brush "#6B7280"
        $window.Resources["BorderBrush"]  = Get-Brush "#E5E7EB"
        $window.Resources["InputBgBrush"] = Get-Brush "#FFFFFF"
        $btnTheme.Content = "Dark Mode"
        Add-Log "Theme: Light"
    }
})

# ---------------------------------------------------------
# Log buttons
# ---------------------------------------------------------
$btnCopyLog.Add_Click({
    try {
        [System.Windows.Clipboard]::SetText($global:LogBuffer.ToString())
        $txtStatus.Text = "Log copied"
        Add-Log "Log copied to clipboard."
    } catch {
        $txtStatus.Text = "Copy failed"
    }
})

$btnClearLog.Add_Click({
    $global:LogBuffer.Clear() | Out-Null
    $logPanel.Children.Clear()
    $txtStatus.Text = "Log cleared"
})

# ---------------------------------------------------------
# Browse
# ---------------------------------------------------------
$btnBrowse.Add_Click({
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select a folder to save the video"
    $folderDialog.ShowNewFolderButton = $true

    if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $inputPath.Text = $folderDialog.SelectedPath
        Add-Log "Save path updated: $($inputPath.Text)"
    }
})

# ---------------------------------------------------------
# Download Button Logic
# ---------------------------------------------------------
$btnDownload.Add_Click({
    $rawUrl  = $inputUrl.Text
    $saveDir = $inputPath.Text

    if ([string]::IsNullOrWhiteSpace($rawUrl)) {
        Show-Err "Please enter a URL."
        return
    }
    if (-not (Test-Path $saveDir)) {
        Show-Err "The save directory does not exist."
        return
    }

    # Lock UI
    $btnDownload.IsEnabled = $false
    $btnDownload.Content = "Processing..."
    $txtStatus.Text = "Working..."
    Add-Log "Starting process..."
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $uri = Normalize-Url $rawUrl
        $urlHost = $uri.Host.ToLower()
        
        # Route based on domain
        if ($urlHost -match "youtube.com" -or $urlHost -match "youtu.be" -or $urlHost -match "instagram.com" -or $urlHost -match "facebook.com" -or $urlHost -match "fb.watch") {
            # Use Native yt-dlp for YouTube/Instagram/Facebook
            Add-Log "Detected link for native engine."
            Download-Native-YtDlp -url $uri.AbsoluteUri -saveDir $saveDir
            
            # Clean up engine immediately after use
            Cleanup-Environment
            Add-Log "Engine files cleaned up."

            $txtStatus.Text = "Ready"
            $txtProgress.Text = ""
            $prgBar.Value = 0
            Add-Log "Success! Video downloaded."
            Show-Info "Download finished." "Success"
        }
        else {
            # Use APIs for others
            $downloadData = $null
            
            if ($urlHost -match "tiktok.com") {
                Add-Log "Detected TikTok link."
                $downloadData = Download-TikTok -url $uri.AbsoluteUri
            }
            else {
                Add-Log "Unknown platform. Trying direct download..."
                $downloadData = Download-DirectMedia -uri $uri
            }
            
            # Perform standard web request WITH PROGRESS
            $fullPath = Join-Path -Path $saveDir -ChildPath $downloadData.fileName
            Add-Log "Downloading to: $fullPath"
            
            Download-File-WithProgress -Url $downloadData.url -Path $fullPath -Headers $downloadData.headers -LogName "Video"

            $txtStatus.Text = "Ready"
            Add-Log "Success! File saved."
            Show-Info "Saved to: $fullPath" "Success"
        }
    }
    catch {
        $txtStatus.Text = "Error"
        $txtProgress.Text = ""
        Add-Log "Error: $($_.Exception.Message)"
        Show-Err "Error: $($_.Exception.Message)"
    }
    finally {
        $btnDownload.IsEnabled = $true
        $btnDownload.Content = "Download Video"
        $prgBar.Value = 0
    }
})

# Initial log line
Add-Log "Ready. Paste a link. (YT/Insta/FB auto-install engine)."

# Run UI
try {
    $null = $window.ShowDialog()
}
finally {
    # CLEANUP ON EXIT
    Cleanup-Environment
}