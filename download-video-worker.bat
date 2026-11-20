@echo off
setlocal enabledelayedexpansion

:: Called by download-video.bat resume
:: %1 = Line number in the queue file (1-based)
:: %2 = Path to the queue file  (format: HEIGHT;QUAL;HISTFILE;URL  per line)

set "LINENUM=%~1"
set "QFILE=%~2"

set "SCRIPTDIR=%~dp0"
set "SCRIPTDIR=!SCRIPTDIR:~0,-1!"

:: Read the specific line from the queue file
set /a CUR=0
set "H="
for /f "usebackq delims=" %%L in ("!QFILE!") do (
    set /a CUR+=1
    if !CUR! equ !LINENUM! (
        :: Parse the line: HEIGHT;QUAL;HISTFILE;URL
        for /f "tokens=1-4 delims=;" %%A in ("%%L") do (
            set "H=%%A"
            set "QUAL=%%B"
            set "HISTFILE=%%C"
            set "URL=%%D"
        )
    )
)

if "!H!"=="" (
    echo ERROR: Could not read entry !LINENUM! from queue file.
    pause >nul
    exit /b 1
)

:: Fetch title for display and history
set "VIDTITLE=Unknown Title"
for /f "delims=" %%i in ('yt-dlp --get-title "!URL!" 2^>nul') do set "VIDTITLE=%%i"
set "VIDTITLE=!VIDTITLE:"=!"
set "VIDTITLE=!VIDTITLE:;=,!"

title Resuming: !VIDTITLE!

echo ===================================================
echo  Resuming: !VIDTITLE!
echo  Quality : !QUAL!
echo  URL     : !URL!
echo ===================================================
echo.

set "FMT=bv*[height<=!H!]+ba/b[height<=!H!]"

set "COOKIE_OPT="
if exist "!SCRIPTDIR!\youtube.com_cookies.txt" set "COOKIE_OPT=--cookies ""!SCRIPTDIR!\youtube.com_cookies.txt"""
if exist "!SCRIPTDIR!\www.youtube.com_cookies.txt" set "COOKIE_OPT=--cookies ""!SCRIPTDIR!\www.youtube.com_cookies.txt"""

yt-dlp.exe -c !COOKIE_OPT! -f "!FMT!" --merge-output-format mp4 --postprocessor-args "ffmpeg:-c:v libx264 -pix_fmt yuv420p -profile:v main -level 4.0 -c:a aac -b:a 192k" "!URL!"

if !errorlevel! equ 0 (
    set "STATUS=SUCCESS"
    echo.
    echo Download completed successfully!
) else (
    set "STATUS=FAILED"
    echo.
    echo Download FAILED or was interrupted again.
)

echo !DATE! !TIME!;!QUAL!;!VIDTITLE!;!URL!;!STATUS!>> "!HISTFILE!"
echo History updated: !STATUS!
echo.
echo Press any key to close this window...
pause >nul
