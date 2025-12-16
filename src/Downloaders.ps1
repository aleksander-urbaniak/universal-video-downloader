. "$PSScriptRoot/Utilities.ps1"
. "$PSScriptRoot/Logging.ps1"

$script:TempToolDir = Join-Path $env:TEMP ("UVD_" + [Guid]::NewGuid().ToString().Substring(0, 8))

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
            throw "Failed to download yt-dlp: $($_.Exception.Message)"
        }
    }
    $exePath
}

function Cleanup-Environment {
    if (Test-Path $script:TempToolDir) {
        try {
            Remove-Item -Path $script:TempToolDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {}
    }
}

function Download-TikTok ($Url) {
    Add-Log "Connecting to TikTok API..."
    [System.Windows.Forms.Application]::DoEvents()

    $apiUrl = "https://www.tikwm.com/api/"
    $payload = @{ url = $Url }
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

function Download-Universal ($Url) {
    Add-Log "Connecting to Universal API..."
    [System.Windows.Forms.Application]::DoEvents()

    $apiUrl = "https://api.cobalt.tools/api/json"
    $payload = @{
        url = $Url
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

function Download-Native-YtDlp {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$SaveDir,
        [System.Windows.Controls.ProgressBar]$ProgressBar,
        [System.Windows.Controls.TextBlock]$StatusBlock,
        [System.Windows.Controls.TextBlock]$ProgressDetails
    )

    $exe = Install-YtDlp -ProgressBar $ProgressBar -StatusBlock $StatusBlock -ProgressDetails $ProgressDetails

    Add-Log "Starting download engine..."
    [System.Windows.Forms.Application]::DoEvents()

    $outputTemplate = Join-Path $SaveDir "%(title)s.%(ext)s"
    $argsList = "-f best --no-mtime -o `"$outputTemplate`" `"$Url`""

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

    $regex = '\[download\]\s+(\d+\.\d+)%\s+of\s+(?:~)?([\d\.]+\w+)\s+at\s+(?:~)?([\d\.]+\w+/s)'

    while (-not $p.HasExited) {
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

    if ($p.ExitCode -ne 0) {
        $err = $p.StandardError.ReadToEnd()
        throw "yt-dlp error: $err"
    }
}

function Download-DirectMedia([uri]$Uri) {
    Add-Log "Direct URL mode..."
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
