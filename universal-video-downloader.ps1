#requires -Version 5.1
# Universal Video Downloader
# - Modern WPF UI
# - Dark/Light theme toggle
# - Integrated Color Log with Copy/Clear support
# - Status Bar with Progress, Speed, and Size
# - Engine: yt-dlp (Auto-install/Auto-remove) + TikWM/Cobalt APIs

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http

$version = "v1.0.2"
$moduleRoot = Join-Path $PSScriptRoot "src"

. (Join-Path $moduleRoot "Utilities.ps1")
. (Join-Path $moduleRoot "Logging.ps1")
. (Join-Path $moduleRoot "Downloaders.ps1")

$xamlPath = Join-Path $moduleRoot "MainWindow.xaml"
if (-not (Test-Path $xamlPath)) {
    Write-Error "XAML file missing at $xamlPath"
    exit 1
}

[xml]$xaml = Get-Content -Path $xamlPath -Raw
$reader = New-Object System.Xml.XmlNodeReader $xaml
try {
    $window = [Windows.Markup.XamlReader]::Load($reader)
}
catch {
    Write-Error "Error parsing XAML: $($_.Exception.Message)"
    exit 1
}

$btnTheme    = $window.FindName("ThemeToggleBtn")
$inputUrl    = $window.FindName("InputUrl")
$inputPath   = $window.FindName("InputPath")
$btnBrowse   = $window.FindName("BtnBrowse")
$btnDownload = $window.FindName("BtnDownload")
$btnStop     = $window.FindName("BtnStop")
$txtStatus   = $window.FindName("TxtStatus")
$txtProgress = $window.FindName("TxtProgressDetails")
$prgBar      = $window.FindName("PrgBar")
$txtVersion  = $window.FindName("TxtVersion")

$logPanel    = $window.FindName("LogPanel")
$logScroll   = $window.FindName("LogScroll")
$btnCopyLog  = $window.FindName("BtnCopyLog")
$btnClearLog = $window.FindName("BtnClearLog")

# New UI Controls
$chkAudioOnly     = $window.FindName("ChkAudioOnly")
$comboRes         = $window.FindName("ComboResolution")
$comboAudioFormat = $window.FindName("ComboAudioFormat")

$inputPath.Text = [Environment]::GetFolderPath("Desktop")
if ($txtVersion) { $txtVersion.Text = $version }

Initialize-Logging -LogPanel $logPanel -LogScroll $logScroll

# --- UI LOGIC EVENTS ---

$updateUiState = {
    $url = $inputUrl.Text
    $isAudio = $chkAudioOnly.IsChecked
    
    # Simple regex for YouTube domain
    $isYoutube = $url -match 'https?://(www\.)?(youtube\.com|youtu\.be)'

    # Resolution Visibility: Show only if YouTube AND Not Audio Only
    if ($isYoutube -and -not $isAudio) {
        $comboRes.Visibility = "Visible"
    } else {
        $comboRes.Visibility = "Collapsed"
    }

    # Audio Format Enable/Disable
    $comboAudioFormat.IsEnabled = $isAudio
}

$inputUrl.Add_TextChanged($updateUiState)
$chkAudioOnly.Add_Click($updateUiState)

# -----------------------

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
    }
    else {
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

$btnCopyLog.Add_Click({
    try {
        Copy-LogBuffer
        $txtStatus.Text = "Log copied"
        Add-Log "Log copied to clipboard."
    }
    catch {
        $txtStatus.Text = "Copy failed"
    }
})

$btnClearLog.Add_Click({
    Clear-LogBuffer
    $txtStatus.Text = "Log cleared"
})

$btnBrowse.Add_Click({
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select a folder to save the video"
    $folderDialog.ShowNewFolderButton = $true

    if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $inputPath.Text = $folderDialog.SelectedPath
        Add-Log "Save path updated: $($inputPath.Text)"
    }
})

$btnStop.Add_Click({
    Request-Cancellation
    $txtStatus.Text = "Stopping..."
    $btnStop.IsEnabled = $false
    Add-Log "Stopping download..."
})

$btnDownload.Add_Click({
    $rawUrl  = $inputUrl.Text
    $saveDir = $inputPath.Text
    
    # Get Options
    $isAudioOnly = $chkAudioOnly.IsChecked
    $selectedRes = $comboRes.Text
    $selectedFmt = $comboAudioFormat.Text

    if ([string]::IsNullOrWhiteSpace($rawUrl)) {
        Show-Err "Please enter a URL."
        return
    }
    if (-not (Test-Path $saveDir)) {
        Show-Err "The save directory does not exist."
        return
    }

    # UI State: Running
    $btnDownload.IsEnabled = $false
    $btnStop.IsEnabled = $true
    $btnDownload.Content = "Processing..."
    $txtStatus.Text = "Working..."
    Reset-Cancellation
    
    Add-Log "Starting process..."
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $uri = Normalize-Url $rawUrl
        $urlHost = $uri.Host.ToLower()

        if ($urlHost -match "youtube.com" -or $urlHost -match "youtu.be" -or $urlHost -match "instagram.com" -or $urlHost -match "facebook.com" -or $urlHost -match "fb.watch") {
            Add-Log "Detected link for native engine."
            
            $resToPass = "Best"
            if (($urlHost -match "youtube.com" -or $urlHost -match "youtu.be") -and -not $isAudioOnly) {
                $resToPass = $selectedRes
            }

            Download-Native-YtDlp -Url $uri.AbsoluteUri -SaveDir $saveDir -ProgressBar $prgBar -StatusBlock $txtStatus -ProgressDetails $txtProgress -AudioOnly $isAudioOnly -Resolution $resToPass -AudioFormat $selectedFmt

            Cleanup-Environment
            Add-Log "Engine files cleaned up."

            $txtStatus.Text = "Ready"
            $txtProgress.Text = ""
            $prgBar.Value = 0
            Add-Log "Success! Download finished."
            Show-Info "Download finished." "Success"
        }
        else {
            $downloadData = $null

            if ($urlHost -match "tiktok.com") {
                Add-Log "Detected TikTok link."
                $downloadData = Download-TikTok -Url $uri.AbsoluteUri -AudioOnly $isAudioOnly
            }
            else {
                Add-Log "Unknown platform. Trying direct download..."
                $downloadData = Download-DirectMedia -Uri $uri
            }

            $fullPath = Join-Path -Path $saveDir -ChildPath $downloadData.fileName
            Add-Log "Downloading to: $fullPath"

            Download-File-WithProgress -Url $downloadData.url -Path $fullPath -Headers $downloadData.headers -LogName "File" -ProgressBar $prgBar -StatusBlock $txtStatus -ProgressDetails $txtProgress

            $txtStatus.Text = "Ready"
            Add-Log "Success! File saved."
            Show-Info "Saved to: $fullPath" "Success"
        }
    }
    catch {
        if ($_.Exception.Message -eq "Download cancelled.") {
            Add-Log "Process Stopped by User."
            $txtStatus.Text = "Stopped"
        }
        else {
            $txtStatus.Text = "Error"
            Add-Log "Error: $($_.Exception.Message)"
            Show-Err "Error: $($_.Exception.Message)"
        }
        $txtProgress.Text = ""
    }
    finally {
        # UI State: Reset
        $btnDownload.IsEnabled = $true
        $btnStop.IsEnabled = $false
        $btnDownload.Content = "Download"
        $prgBar.Value = 0
    }
})

Add-Log "Ready. Paste a link. (TikTok/Youtube/Instagram/Facebook auto-install engine)."

try {
    $null = $window.ShowDialog()
}
finally {
    Cleanup-Environment
}