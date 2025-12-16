![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge\&logo=windows\&logoColor=white) ![PowerShell 5.1](https://img.shields.io/badge/PowerShell-5.1-5391FE?style=for-the-badge\&logo=powershell\&logoColor=white)

> 🎬✨ Fast, clean downloads with a modern WPF UI.

# Universal Video Downloader

Universal Video Downloader is a Windows PowerShell 5.1 script with a modern WPF interface for saving videos from popular platforms. It auto-installs the yt-dlp engine for YouTube, Instagram, and Facebook, while providing direct API flows for TikTok and general media links. Built-in logging, status indicators, and a light/dark theme make downloads easy to monitor.

## Features 🚀

* **Modern WPF UI** with light/dark theme toggle, inline logging panel, clipboard copy, and clear controls.
* **Multi-engine support** using yt-dlp for major platforms plus TikWM and Cobalt APIs for TikTok and other sites.
* **Inline progress** showing percent, speed, and transferred size for downloads.
* **Self-cleaning** temporary directory for yt-dlp after downloads finish.

## Requirements 📋

* Windows with PowerShell **5.1** (WPF requires full .NET Framework).
* Network access to fetch yt-dlp and call TikTok/Cobalt APIs.

## Project Structure 📂

* `universal-video-downloader.ps1`: Entry point that loads the XAML window, wires up UI events, and delegates to helper modules.
* `src/MainWindow.xaml`: Defines the WPF window layout, resources, and control names used by the script.
* `src/Utilities.ps1`: General helpers for brush creation, message dialogs, safe filenames, size formatting, and URL normalization.
* `src/Logging.ps1`: Log buffer management plus UI rendering, clipboard copy, and clear helpers.
* `src/Downloaders.ps1`: Download workflows, including engine bootstrap (yt-dlp), TikTok API client, Cobalt API client, direct media fallback, and a shared download helper with progress reporting.

## Key Functions ⚙️

### Utilities

* `Get-Brush`, `Clean-FileName`, `Format-Size`: UI and file-safety helpers.
* `Show-Err`, `Show-Info`: Consistent message dialogs for errors and info.
* `Normalize-Url`: Cleans and validates user input into an absolute URI.

### Logging

* `Initialize-Logging`: Binds the log buffer to the WPF stack panel and scroll viewer.
* `Add-Log`: Adds a timestamped, color-coded entry to the UI and buffer.
* `Copy-LogBuffer`, `Clear-LogBuffer`: Clipboard copy and buffer reset.

### Downloaders

* `Download-File-WithProgress`: Streams a URL to disk with percent, speed, and size updates.
* `Install-YtDlp` / `Cleanup-Environment`: Fetches and later removes the yt-dlp executable from a temp folder.
* `Download-Native-YtDlp`: Runs yt-dlp for YouTube, Instagram, or Facebook links with live progress parsing.
* `Download-TikTok`: Uses the TikWM API to resolve TikTok media and filename.
* `Download-Universal`: Calls the Cobalt API for other sites when supported.
* `Download-DirectMedia`: Fallback for generic direct URLs, deriving a safe filename.

## Usage 🎮

1. Open **PowerShell 5.1** on Windows and run the script:

   ```powershell
   ./universal-video-downloader.ps1
   ```
2. Paste a video URL and choose a destination folder (defaults to Desktop).
3. Click **Download Video**.

   * YouTube/Instagram/Facebook links trigger an automatic yt-dlp download.
   * TikTok uses the TikWM API.
   * Other links try the Cobalt API first, then fall back to a direct fetch.
4. Monitor progress, copy logs, or clear the log panel as needed. The theme toggle switches between light and dark modes.

## Notes 📝

* The script auto-installs yt-dlp into a temporary folder and cleans it up after use.
* Manual UI testing is recommended for verifying layout and theme changes.
  src/Downloade
