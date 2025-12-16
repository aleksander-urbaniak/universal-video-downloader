$script:LogBuffer = New-Object System.Text.StringBuilder
$script:LogPanel = $null
$script:LogScroll = $null

function Initialize-Logging {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.StackPanel]$LogPanel,
        [Parameter(Mandatory)]
        [System.Windows.Controls.ScrollViewer]$LogScroll
    )

    $script:LogPanel = $LogPanel
    $script:LogScroll = $LogScroll
}

function Add-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $script:LogPanel -or -not $script:LogScroll) {
        throw "Logging not initialized."
    }

    $timestamp = Get-Date -Format "HH:mm:ss"
    $fullMsg = "[$timestamp] $Message"

    $null = $script:LogBuffer.AppendLine($fullMsg)

    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $fullMsg
    $tb.FontFamily = "Consolas"
    $tb.FontSize = 12
    $tb.TextWrapping = "Wrap"
    $tb.Margin = "0,0,0,2"

    if ($Message -match "(?i)(error|failed|exception)") {
        $tb.Foreground = [Windows.Media.Brushes]::IndianRed
        $tb.FontWeight = "Bold"
    }
    elseif ($Message -match "(?i)(success|complete|ready|resolved|finished)") {
        $tb.Foreground = [Windows.Media.Brushes]::SeaGreen
        $tb.FontWeight = "Bold"
    }
    elseif ($Message -match "(?i)(warning|unknown|check)") {
        $tb.Foreground = [Windows.Media.Brushes]::DarkOrange
    }
    else {
        $tb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "TextBrush")
    }

    $script:LogPanel.Children.Add($tb) | Out-Null
    $script:LogScroll.ScrollToBottom()
}

function Copy-LogBuffer {
    [System.Windows.Clipboard]::SetText($script:LogBuffer.ToString())
}

function Clear-LogBuffer {
    $script:LogBuffer.Clear() | Out-Null
    $script:LogPanel.Children.Clear()
}
