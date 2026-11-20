@echo off
setlocal enabledelayedexpansion

:: ==================== CONFIGURATION ====================
:: History file location (same folder as this script)
set "HISTORYFILE=%~dp0download_history.log"
:: ======================================================

echo ===================================================
echo                 YT-DLP VIDEO DOWNLOADER             
echo ===================================================
echo Available Quality Options:
echo    - 2160p / 2160 (4K Ultra HD)
echo    - 1440p / 1440 (2K Quad HD)
echo    - 1080p / 1080 (Full HD - Default)
echo    - 720p  / 720  (Standard HD)
echo    - 480p  / 480  (Standard Definition)
echo    - 360p  / 360  (Low Quality)
echo    - 240p  / 240  (Very Low Quality)
echo ===================================================

:: ---------- Special commands ----------
if /i "%~1"=="list"   goto :show_history
if /i "%~1"=="resume" goto :resume_downloads

set "HEIGHT=480"
set "URL="
set "P_FOUND=Not appended ('p' was omitted or stripped)"

if "%~1"=="" (
    echo ERROR: No video URL provided.
    echo Usage: download-video [quality] [URL]
    echo        download-video list
    echo        download-video resume
    goto :end
)

:: Capture the raw remainder of the command line - survives '=' in URLs
set "ALLARGS=%*"
if "!ALLARGS:~0,1!"==" " set "ALLARGS=!ALLARGS:~1!"

:: Extract just the first token to inspect it
for /f "tokens=1*" %%a in ("!ALLARGS!") do (
    set "FIRSTWORD=%%a"
    set "REST=%%b"
)
set "FIRSTWORD_CLEAN=!FIRSTWORD:"=!"

if /i "!FIRSTWORD_CLEAN:~0,4!"=="http" (
    set "URL=!ALLARGS!"
) else (
    set "URL=!REST!"

    set "STR_CHECK=!FIRSTWORD_CLEAN:p=!"
    set "STR_CHECK=!STR_CHECK:P=!"
    if not "!STR_CHECK!"=="!FIRSTWORD_CLEAN!" (
        set "P_FOUND=Appended ('p' was explicitly found and handled!)"
    )

    for /f "delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" %%a in ("!FIRSTWORD_CLEAN!") do set "HEIGHT=%%a"
)

set "URL=!URL:"=!"

if "!URL!"=="" (
    echo ERROR: Missing video URL argument.
    echo Usage: download-video 480p "https://link..."
    goto :end
)

echo Target Maximum Resolution: %HEIGHT%p
echo Letter 'p' Status:        %P_FOUND%
echo Target URL:                %URL%
echo Codec Preference:          Enforcing WhatsApp/Universal Compatibility (H.264 + AAC + yuv420p)

:: ---------- Get video title for the history ----------
echo Fetching video title...
set "VIDTITLE=Unknown Title"
for /f "delims=" %%i in ('yt-dlp --get-title "%URL%" 2^>nul') do set "VIDTITLE=%%i"
:: Remove any double quotes and replace the delimiter character ';' with ','
set "VIDTITLE=!VIDTITLE:"=!"
set "VIDTITLE=!VIDTITLE:;=,!"
echo Title: !VIDTITLE!

echo Processing download and transcoding...
echo ===================================================

:: ---------- Execute download with Universal Transcode ----------
set "COOKIE_OPT="
if exist "%~dp0youtube.com_cookies.txt" set "COOKIE_OPT=--cookies ""%~dp0youtube.com_cookies.txt"""
if exist "%~dp0www.youtube.com_cookies.txt" set "COOKIE_OPT=--cookies ""%~dp0www.youtube.com_cookies.txt"""

yt-dlp.exe !COOKIE_OPT! -f "bv*[height<=%HEIGHT%]+ba/b[height<=%HEIGHT%]" --merge-output-format mp4 --postprocessor-args "ffmpeg:-c:v libx264 -pix_fmt yuv420p -profile:v main -level 4.0 -c:a aac -b:a 192k" "%URL%"

:: ---------- Determine success / failure ----------
if %errorlevel% equ 0 (
    set "STATUS=SUCCESS"
    echo Download completed and transcoded successfully.
) else (
    set "STATUS=FAILED"
    echo Download FAILED or was interrupted.
)

:: ---------- Write entry to history log ----------
echo %DATE% %TIME%;%HEIGHT%p;!VIDTITLE!;%URL%;!STATUS!>> "%HISTORYFILE%"
echo History entry saved.

goto :end


:: ==========================================================
:resume_downloads
:: ==========================================================
setlocal enabledelayedexpansion

if not exist "%HISTORYFILE%" (
    echo No download history found. Nothing to resume.
    goto :end
)

:: Prepare ANSI escape codes
for /f %%e in ('echo prompt $e^| cmd') do set "ESC=%%e"
set "GREEN=%ESC%[32m"
set "YELLOW=%ESC%[33m"
set "CYAN=%ESC%[36m"
set "RED=%ESC%[31m"
set "BOLD=%ESC%[1m"
set "RESET=%ESC%[0m"

echo.
echo ===================================================
echo           SCANNING FOR INCOMPLETE DOWNLOADS        
echo ===================================================
echo.

:: -------------------------------------------------------
:: Pass 1 - Collect every URL that ever had a SUCCESS
:: We write them to a temp file so we can check against it
:: -------------------------------------------------------
set "TMPOK=%TEMP%\dlv_ok_%RANDOM%.tmp"
set "TMPFAIL=%TEMP%\dlv_fail_%RANDOM%.tmp"
set "TMPQUEUE=%TEMP%\dlv_queue_%RANDOM%.tmp"
if exist "%TMPOK%"    del "%TMPOK%"
if exist "%TMPFAIL%"  del "%TMPFAIL%"
if exist "%TMPQUEUE%" del "%TMPQUEUE%"

for /f "usebackq tokens=1-5 delims=;" %%A in ("%HISTORYFILE%") do (
    set "R_STATUS=%%E"
    set "R_URL=%%D"
    for /f "tokens=*" %%x in ("!R_STATUS!") do set "R_STATUS=%%x"
    for /f "tokens=*" %%x in ("!R_URL!")    do set "R_URL=%%x"
    if /i "!R_STATUS!"=="SUCCESS" (
        echo !R_URL!>> "%TMPOK%"
    )
)

:: -------------------------------------------------------
:: Pass 2 - Collect FAILED entries whose URL is NOT in OK
:: Keep only the LAST FAILED entry per URL
:: -------------------------------------------------------
set /a TOTAL_FAILED=0

for /f "usebackq tokens=1-5 delims=;" %%A in ("%HISTORYFILE%") do (
    set "R_DT=%%A"
    set "R_QUAL=%%B"
    set "R_TITLE=%%C"
    set "R_URL=%%D"
    set "R_STATUS=%%E"

    for /f "tokens=*" %%x in ("!R_STATUS!") do set "R_STATUS=%%x"
    for /f "tokens=*" %%x in ("!R_URL!")    do set "R_URL=%%x"
    for /f "tokens=*" %%x in ("!R_QUAL!")   do set "R_QUAL=%%x"
    for /f "tokens=*" %%x in ("!R_TITLE!")  do set "R_TITLE=%%x"
    for /f "tokens=*" %%x in ("!R_DT!")     do set "R_DT=%%x"

    if /i "!R_STATUS!"=="FAILED" (
        :: Check if this URL ever succeeded
        set "ALREADY_OK=0"
        if exist "%TMPOK%" (
            findstr /x /c:"!R_URL!" "%TMPOK%" >nul 2>&1
            if not errorlevel 1 set "ALREADY_OK=1"
        )
        if "!ALREADY_OK!"=="0" (
            :: Store/overwrite so we always keep the latest FAILED for this URL
            set "ENTRY_!R_URL!"=!R_DT!;!R_QUAL!;!R_TITLE!;!R_URL!
        )
    )
)

:: -------------------------------------------------------
:: Pass 3 - Walk the history once more in order to output
:: unique pending URLs in chronological order
:: -------------------------------------------------------
set /a IDX=0

:: We'll use a second temp file to track seen URLs
set "TMPSEEN=%TEMP%\dlv_seen_%RANDOM%.tmp"
if exist "%TMPSEEN%" del "%TMPSEEN%"

for /f "usebackq tokens=1-5 delims=;" %%A in ("%HISTORYFILE%") do (
    set "R_STATUS=%%E"
    set "R_URL=%%D"
    set "R_QUAL=%%B"
    set "R_TITLE=%%C"
    set "R_DT=%%A"

    for /f "tokens=*" %%x in ("!R_STATUS!") do set "R_STATUS=%%x"
    for /f "tokens=*" %%x in ("!R_URL!")    do set "R_URL=%%x"
    for /f "tokens=*" %%x in ("!R_QUAL!")   do set "R_QUAL=%%x"
    for /f "tokens=*" %%x in ("!R_TITLE!")  do set "R_TITLE=%%x"
    for /f "tokens=*" %%x in ("!R_DT!")     do set "R_DT=%%x"

    if /i "!R_STATUS!"=="FAILED" (
        set "ALREADY_OK=0"
        if exist "%TMPOK%" (
            findstr /x /c:"!R_URL!" "%TMPOK%" >nul 2>&1
            if not errorlevel 1 set "ALREADY_OK=1"
        )
        if "!ALREADY_OK!"=="0" (
            :: Check if we already queued this URL
            set "SEEN=0"
            if exist "%TMPSEEN%" (
                findstr /x /c:"!R_URL!" "%TMPSEEN%" >nul 2>&1
                if not errorlevel 1 set "SEEN=1"
            )
            if "!SEEN!"=="0" (
                echo !R_URL!>> "%TMPSEEN%"
                set /a IDX+=1
                set "Q_URL_!IDX!=!R_URL!"
                set "Q_QUAL_!IDX!=!R_QUAL!"
                set "Q_TITLE_!IDX!=!R_TITLE!"
                set "Q_DT_!IDX!=!R_DT!"
            )
        )
    )
)

:: Cleanup temp files
if exist "%TMPOK%"   del "%TMPOK%"
if exist "%TMPSEEN%" del "%TMPSEEN%"

:: -------------------------------------------------------
:: Display the pending list
:: -------------------------------------------------------
if %IDX% equ 0 (
    echo %GREEN%All downloads in history have already completed successfully!%RESET%
    echo Nothing to resume.
    goto :resume_end
)

echo %YELLOW%Found %IDX% incomplete download(s) that need resuming:%RESET%
echo.

set /a I=1
:display_loop
if %I% gtr %IDX% goto :display_done
    set "DT=!Q_DT_%I%!"
    set "QUAL=!Q_QUAL_%I%!"
    set "TITLE=!Q_TITLE_%I%!"
    set "URL=!Q_URL_%I%!"
    echo   %CYAN%[%I%]%RESET% !TITLE!
    echo       Quality : !QUAL!
    echo       URL     : !URL!
    echo       Failed  : !DT!
    echo.
    set /a I+=1
goto :display_loop
:display_done

echo ===================================================
echo  Each download will open in its own terminal window.
echo  yt-dlp will auto-resume any partial (.part) file.
echo ===================================================
echo.
echo Opening resume terminals...
echo.

:: Strip trailing backslash from script dir so /D "path\" doesn't break quoting
set "SCRIPTDIR=%~dp0"
set "SCRIPTDIR=!SCRIPTDIR:~0,-1!"

:: Write a queue file: one line per download, format = HEIGHT;QUAL;HISTFILE;URL
:: Using a file avoids passing URLs (which contain ? = &) as bat arguments
set "QUEUEFILE=%TEMP%\dlv_queue_%RANDOM%.txt"
if exist "!QUEUEFILE!" del "!QUEUEFILE!"

set /a I=1
:write_queue
if %I% gtr %IDX% goto :write_queue_done
    set "QUAL=!Q_QUAL_%I%!"
    set "URL=!Q_URL_%I%!"
    set "H=!QUAL:p=!"
    set "H=!H:P=!"
    echo !H!;!QUAL!;!HISTORYFILE!;!URL!>> "!QUEUEFILE!"
    set /a I+=1
goto :write_queue
:write_queue_done

:: Launch one minimized worker window per line in the queue file
set /a I=1
:open_loop
if %I% gtr %IDX% goto :open_done

    set "TITLE=!Q_TITLE_%I%!"

    start /MIN "Resuming: !TITLE!" /D "!SCRIPTDIR!" cmd /k ""!SCRIPTDIR!\download-video-worker.bat" "!I!" "!QUEUEFILE!""

    echo   %GREEN%[%I%/%IDX%]%RESET% Terminal opened for: !TITLE!
    set /a I+=1
    timeout /t 1 /nobreak >nul

goto :open_loop
:open_done

echo.
echo %GREEN%All %IDX% resume terminal(s) launched!%RESET%
echo Each terminal will automatically log SUCCESS or FAILED
echo to the history file when it finishes.
echo.

:resume_end
if exist "%TMPFAIL%"  del "%TMPFAIL%"  2>nul
if exist "%TMPQUEUE%" del "%TMPQUEUE%" 2>nul
endlocal
goto :end


:: ==========================================================
:show_history
:: ==========================================================
setlocal enabledelayedexpansion
if not exist "%HISTORYFILE%" (
    echo No download history found.
    goto :end
)

:: Prepare ANSI escape character for colors (works on Windows 10+)
for /f %%e in ('echo prompt $e^| cmd') do set "ESC=%%e"
set "GREEN=%ESC%[32m"
set "RED=%ESC%[31m"
set "RESET=%ESC%[31m"
set "RESET=%ESC%[0m"

echo ===================================================
echo                    DOWNLOAD HISTORY                 
echo ===================================================
set /a COUNT=0
for /f "usebackq tokens=1-5 delims=;" %%A in ("%HISTORYFILE%") do (
    set /a COUNT+=1
    set "DT=%%A"
    set "QUAL=%%B"
    set "TITLE=%%C"
    set "LINK=%%D"
    set "RESULT=%%E"

    :: Trim spaces (just in case)
    for /f "tokens=*" %%a in ("!DT!")     do set "DT=%%a"
    for /f "tokens=*" %%a in ("!QUAL!")   do set "QUAL=%%a"
    for /f "tokens=*" %%a in ("!TITLE!")  do set "TITLE=%%a"
    for /f "tokens=*" %%a in ("!LINK!")   do set "LINK=%%a"
    for /f "tokens=*" %%a in ("!RESULT!") do set "RESULT=%%a"

    :: Color the status
    if /i "!RESULT!"=="SUCCESS" (
        set "COLSTAT=%GREEN%SUCCESS%RESET%"
    ) else (
        set "COLSTAT=%RED%FAILED%RESET%"
    )

    echo [!COUNT!] %DT%
    echo     Quality : !QUAL!
    echo     Title   : !TITLE!
    echo     URL     : !LINK!
    echo     Status  : !COLSTAT!
    echo -------------------------------------------
)
if %COUNT% equ 0 echo (history file is empty)
endlocal
goto :end


:end
endlocal
