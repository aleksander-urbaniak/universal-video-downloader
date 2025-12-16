function Get-Brush ([string]$Hex) {
    [Windows.Media.BrushConverter]::new().ConvertFrom($Hex)
}

function Clean-FileName ([string]$Name) {
    $Name -replace '[\\/:*?"<>|]', ''
}

function Show-Err([string]$Text, [string]$Caption = "Error") {
    [System.Windows.Forms.MessageBox]::Show(
        $Text,
        $Caption,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Show-Info([string]$Text, [string]$Caption = "Info") {
    [System.Windows.Forms.MessageBox]::Show(
        $Text,
        $Caption,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Format-Size ([double]$Bytes) {
    if ($Bytes -lt 1KB) { return "{0:N2} B" -f $Bytes }
    if ($Bytes -lt 1MB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    if ($Bytes -lt 1GB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    "{0:N2} GB" -f ($Bytes / 1GB)
}

function Remove-InvisibleChars([string]$Value) {
    if ($null -eq $Value) { return $Value }
    $Value = $Value -replace "[\u200B\u200C\u200D\u2060\uFEFF]", ""
    $Value -replace "[\u00A0]", " "
}

function Normalize-Url([string]$Raw) {
    $Raw = Remove-InvisibleChars $Raw
    $Raw = $Raw.Trim()

    if ($Raw -match '^(www\.)') {
        $Raw = "https://$Raw"
    }
    elseif ($Raw -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
        $Raw = "https://$Raw"
    }

    $uri = $null
    if (-not [System.Uri]::TryCreate($Raw, [System.UriKind]::Absolute, [ref]$uri)) {
        throw "Invalid URL format."
    }
    $uri
}
