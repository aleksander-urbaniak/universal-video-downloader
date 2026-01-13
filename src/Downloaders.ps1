. "$PSScriptRoot/Utilities.ps1"
. "$PSScriptRoot/Logging.ps1"

$script:TempToolDir = Join-Path $env:TEMP ("UVD_" + [Guid]::NewGuid().ToString().Substring(0, 8))
$script:cancelRequest = $false
$script:currentProcess = $null

function Reset-Cancellation {
    $script:cancelRequest = $false
}

function Request-Cancellation {
    $script:cancelRequest = $true
    if ($script:currentProcess -and -not $script:currentProcess.HasExited) {
        try { $script:currentProcess.Kill() } catch {}
    }
}

function Check-Cancellation {
    if ($script:cancelRequest) {
        throw "Download cancelled."
    }
}

function Download-File-WithProgress {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Path,
        [hashtable]$Headers = $null,
        [string]$LogName = "File",
        [System.Windows.Controls.ProgressBar]$ProgressBar,
        [System.Windows.Controls.TextBlock]$StatusBlock,
        [System.Windows.Controls.TextBlock]$ProgressDetails
    )

    $httpClient = New-Object System.Net.Http.HttpClient
    if ($Headers) {
        foreach ($key in $Headers.Keys) {
            if ($key -eq "User-Agent") {
                $httpClient.DefaultRequestHeaders.UserAgent.ParseAdd($Headers[$key])
            }
            else {
                $httpClient.DefaultRequestHeaders.TryAddWithoutValidation($key, $Headers[$key]) | Out-Null
            }
        }
    }

    try {
        Check-Cancellation
        $response = $httpClient.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
        if (-not $response.IsSuccessStatusCode) {
            throw "HTTP Error: $($response.StatusCode)"
        }

        $totalBytes = $response.Content.Headers.ContentLength
        if ($null -eq $totalBytes) { $totalBytes = -1 }

        $remoteStream = $response.Content.ReadAsStreamAsync().Result
        $fileStream = [System.IO.File]::Create($Path)

        $buffer = New-Object byte[] 65536
        $totalRead = 0
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $lastUpdate = 0

        if ($ProgressBar) {
            $ProgressBar.Value = 0
            $ProgressBar.IsIndeterminate = if ($totalBytes -eq -1) { $true } else { $false }
        }

        do {
            Check-Cancellation
            $readCount = $remoteStream.Read($buffer, 0, $buffer.Length)
            if ($readCount -gt 0) {
                $fileStream.Write($buffer, 0, $readCount)
                $totalRead += $readCount

                if ($sw.ElapsedMilliseconds -gt $lastUpdate + 100) {
                    $speed = 0
                    if ($sw.Elapsed.TotalSeconds -gt 0) {
                        $speed = $totalRead / $sw.Elapsed.TotalSeconds
                    }

                    if ($totalBytes -gt 0) {
                        $percent = ($totalRead / $totalBytes) * 100
                        if ($ProgressBar) { $ProgressBar.Value = $percent }
                        if ($StatusBlock) { $StatusBlock.Text = "Downloading $LogName... {0:N0}%" -f $percent }
                        if ($ProgressDetails) { $ProgressDetails.Text = "{0} of {1} @ {2}/s" -f (Format-Size $totalRead), (Format-Size $totalBytes), (Format-Size $speed) }
                    }
                    else {
                        if ($StatusBlock) { $StatusBlock.Text = "Downloading $LogName..." }
                        if ($ProgressDetails) { $ProgressDetails.Text = "{0} @ {1}/s" -f (Format-Size $totalRead), (Format-Size $speed) }
                    }

                    [System.Windows.Forms.Application]::DoEvents()
                    $lastUpdate = $sw.ElapsedMilliseconds
                }
            }
        } while ($readCount -gt 0)

        if ($ProgressBar) { $ProgressBar.Value = 100 }
        if ($StatusBlock) { $StatusBlock.Text = "Complete" }
        if ($ProgressDetails) { $ProgressDetails.Text = "" }
    }
    finally {
        if ($fileStream) { $fileStream.Close(); $fileStream.Dispose() }
        if ($remoteStream) { $remoteStream.Close(); $remoteStream.Dispose() }
        if ($httpClient) { $httpClient.Dispose() }
        
        # Cleanup partial file if cancelled
        if ($script:cancelRequest -and (Test-Path $Path)) {
            Remove-Item $Path -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-YtDlp {
    param(
        [System.Windows.Controls.ProgressBar]$ProgressBar,
        [System.Windows.Controls.TextBlock]$StatusBlock,
        [System.Windows.Controls.TextBlock]$ProgressDetails
    )

    if (-not (Test-Path $script:TempToolDir)) {
        New-Item -Path $script:TempToolDir -ItemType Directory -Force | Out-Null
    }

    $exePath = Join-Path $script:TempToolDir "yt-dlp.exe"

    if (-not (Test-Path $exePath)) {
        Add-Log "Downloading engine (yt-dlp)..."
        [System.Windows.Forms.Application]::DoEvents()

        try {
            Download-File-WithProgress -Url "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" -Path $exePath -LogName "Engine" -ProgressBar $ProgressBar -StatusBlock $StatusBlock -ProgressDetails $ProgressDetails
            Add-Log "Engine ready."
        }
        catch {
            Check-Cancellation
            throw "Failed to download yt-dlp: $($_.Exception.Message)"
        }
    }
    $exePath
}

function Install-FFmpeg {
    param(
        [System.Windows.Controls.ProgressBar]$ProgressBar,
        [System.Windows.Controls.TextBlock]$StatusBlock,
        [System.Windows.Controls.TextBlock]$ProgressDetails
    )

    $ffmpegExe = Join-Path $script:TempToolDir "ffmpeg.exe"
    
    if (-not (Test-Path $ffmpegExe)) {
        Add-Log "FFmpeg required. Downloading..."
        [System.Windows.Forms.Application]::DoEvents()

        $zipUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
        $zipPath = Join-Path $script:TempToolDir "ffmpeg.zip"
        $extractPath = Join-Path $script:TempToolDir "ffmpeg_extract"

        try {
            Download-File-WithProgress -Url $zipUrl -Path $zipPath -LogName "FFmpeg" -ProgressBar $ProgressBar -StatusBlock $StatusBlock -ProgressDetails $ProgressDetails
            
            Check-Cancellation
            Add-Log "Extracting FFmpeg..."
            if ($StatusBlock) { $StatusBlock.Text = "Extracting..." }
            [System.Windows.Forms.Application]::DoEvents()

            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

            $bin = Get-ChildItem -Path $extractPath -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
            if ($bin) {
                Move-Item $bin.FullName $script:TempToolDir -Force
                $probe = Get-ChildItem -Path $extractPath -Recurse -Filter "ffprobe.exe" | Select-Object -First 1
                if ($probe) { Move-Item $probe.FullName $script:TempToolDir -Force }
            }
            else {
                throw "ffmpeg.exe not found in downloaded zip."
            }
        }
        catch {
            Check-Cancellation
            throw "FFmpeg setup failed: $($_.Exception.Message)"
        }
        finally {
             if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
             if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
        }
        Add-Log "FFmpeg ready."
    }
}

function Cleanup-Environment {
    if (Test-Path $script:TempToolDir) {
        try {
            Remove-Item -Path $script:TempToolDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {}
    }
}

function Download-TikTok {
    param(
        $Url,
        [bool]$AudioOnly = $false
    )
    Add-Log "Connecting to TikTok API..."
    [System.Windows.Forms.Application]::DoEvents()

    Check-Cancellation

    $apiUrl = "https://www.tikwm.com/api/"
    $payload = @{ url = $Url }
    $headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }

    $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $payload -Headers $headers -ErrorAction Stop

    if ($response.code -eq 0) {
        $id = $response.data.id
        $author = $response.data.author.unique_id
        
        if ($AudioOnly -and $response.data.music) {
            Add-Log "Audio found: $($response.data.title)"
            $mediaUrl = $response.data.music
            $fileName = "tiktok_audio_${author}_${id}.mp3"
        }
        else {
            Add-Log "Video found: $($response.data.title)"
            $mediaUrl = $response.data.play
            # TikTok API usually gives mp4
            $fileName = "tiktok_${author}_${id}.mp4"
        }

        return @{ url = $mediaUrl; fileName = $fileName }
    }
    throw "TikTok API returned error."
}

function Download-DirectMedia([uri]$Uri) {
    Add-Log "Direct URL mode..."
    Check-Cancellation
    $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    $headers = @{ "User-Agent" = $ua }

    $suggestedName = $null
    try {
        $head = Invoke-WebRequest -Uri $Uri.AbsoluteUri -Method Head -Headers $headers -TimeoutSec 10 -ErrorAction SilentlyContinue
        if ($head) {
             $cd = $head.Headers["Content-Disposition"]
             if ($cd -and $cd -match 'filename="?(?<fn>[^";]+)"?') { $suggestedName = $Matches.fn }
        }
    }
    catch {}

    $base = [System.IO.Path]::GetFileName($Uri.AbsolutePath)
    if (-not $base) { $base = "download" }
    $fileName = if ($suggestedName) { Clean-FileName $suggestedName } else { Clean-FileName $base }
    if (-not [System.IO.Path]::GetExtension($fileName)) { $fileName += ".mp4" }

    @{ url = $Uri.AbsoluteUri; fileName = $fileName; headers = $headers }
}

function Download-Native-YtDlp {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$SaveDir,
        [System.Windows.Controls.ProgressBar]$ProgressBar,
        [System.Windows.Controls.TextBlock]$StatusBlock,
        [System.Windows.Controls.TextBlock]$ProgressDetails,
        [bool]$AudioOnly = $false,
        [string]$Resolution = "Best",
        [string]$AudioFormat = "Best"
    )

    $exe = Install-YtDlp -ProgressBar $ProgressBar -StatusBlock $StatusBlock -ProgressDetails $ProgressDetails
    Install-FFmpeg -ProgressBar $ProgressBar -StatusBlock $StatusBlock -ProgressDetails $ProgressDetails

    Add-Log "Starting download engine..."
    [System.Windows.Forms.Application]::DoEvents()
    Check-Cancellation

    # Ensure output has correct extension. For video, we will force merge to mp4.
    $outputTemplate = Join-Path $SaveDir "%(title)s.%(ext)s"
    $ffmpegArg = "--ffmpeg-location `"$script:TempToolDir`""

    # Construct arguments
    if ($AudioOnly) {
        if ($AudioFormat -eq "Best") {
             $argsList = "$ffmpegArg -f `"bestaudio/best`" --no-mtime -o `"$outputTemplate`" `"$Url`""
        }
        elseif ($AudioFormat -eq "m4a") {
             $argsList = "$ffmpegArg -f `"bestaudio[ext=m4a]/best[ext=m4a]/best`" --no-mtime -o `"$outputTemplate`" `"$Url`""
        }
        elseif ($AudioFormat -eq "mp3") {
             $argsList = "$ffmpegArg -f `"bestaudio/best`" --extract-audio --audio-format mp3 --no-mtime -o `"$outputTemplate`" `"$Url`""
        }
        else {
             $argsList = "$ffmpegArg -f `"bestaudio/best`" --extract-audio --audio-format $AudioFormat --no-mtime -o `"$outputTemplate`" `"$Url`""
        }
        Add-Log "Mode: Audio Only ($AudioFormat)"
    }
    else {
        # Video Mode with Resolution Selection + Force MP4 Merge
        $format = "best"
        if ($Resolution -ne "Best") {
            $height = $Resolution -replace "p",""
            $format = "bestvideo[height<=$height]+bestaudio/best[height<=$height]"
            Add-Log "Target Resolution: $Resolution"
        }
        
        # Added --merge-output-format mp4 to force container
        $argsList = "$ffmpegArg -f `"$format`" --merge-output-format mp4 --no-mtime -o `"$outputTemplate`" `"$Url`""
    }

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $exe
    $pinfo.Arguments = $argsList
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $script:currentProcess = $p
    
    $p.Start() | Out-Null

    $regex = '\[download\]\s+(\d+\.\d+)%\s+of\s+(?:~)?([\d\.]+\w+)\s+at\s+(?:~)?([\d\.]+\w+/s)'

    try {
        while (-not $p.HasExited) {
            Check-Cancellation
            $line = $p.StandardOutput.ReadLine()
            if ($line) {
                if ($line -match $regex) {
                    $percent = $Matches[1]
                    $size = $Matches[2]
                    $speed = $Matches[3]

                    if ($ProgressBar) { $ProgressBar.Value = [double]$percent }
                    if ($StatusBlock) { $StatusBlock.Text = "Downloading... $percent%" }
                    if ($ProgressDetails) { $ProgressDetails.Text = "$size @ $speed" }
                }
                else {
                     Add-Log "yt: $line"
                }
            }
            [System.Windows.Forms.Application]::DoEvents()
        }
        Check-Cancellation
    }
    finally {
        if (-not $p.HasExited) {
            try { $p.Kill() } catch {}
        }
        $script:currentProcess = $null
    }

    if ($p.ExitCode -ne 0) {
        $err = $p.StandardError.ReadToEnd()
        $p.Dispose()
        if ($script:cancelRequest) { throw "Download cancelled." }
        throw "yt-dlp error: $err"
    }
    $p.Dispose()
}