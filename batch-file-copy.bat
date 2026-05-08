@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM  Configuration - Set your source and destination directories
REM ============================================================
set "SOURCE_DIR=C:\Path\To\Source"
set "DEST_DIR=C:\Path\To\Destination"

REM Cutoff date for folder modification time (MM-DD-YYYY format for xcopy /D:)
REM Folders modified on or after this date will be processed.
set "CUTOFF_DATE=01-01-2024"

REM Numeric form (YYYYMMDD) used for our own date comparison
set "CUTOFF_YYYYMMDD=20240101"

REM ============================================================
REM  Create destination folder if it does not already exist
REM ============================================================
if not exist "%DEST_DIR%" (
    echo Creating destination folder: "%DEST_DIR%"
    mkdir "%DEST_DIR%"
)

REM ============================================================
REM  Verify the source directory exists before continuing
REM ============================================================
if not exist "%SOURCE_DIR%" (
    echo ERROR: Source directory does not exist: "%SOURCE_DIR%"
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Starting copy process (most recent file per folder)
echo  Source:      %SOURCE_DIR%
echo  Destination: %DEST_DIR%
echo  Only folders modified on/after: %CUTOFF_DATE%
echo ============================================================
echo.

REM ============================================================
REM  Loop through every subfolder inside SOURCE_DIR
REM  /d means "directories only"
REM ============================================================
for /d %%D in ("%SOURCE_DIR%\*") do (
    echo Processing folder: "%%~nxD"

    REM --------------------------------------------------------
    REM  Get the folder's last-modified date using 'dir' on the
    REM  parent with /tw (write time). Parse the date string and
    REM  convert it to YYYYMMDD for numeric comparison.
    REM --------------------------------------------------------
    set "FOLDER_DATE="
    for /f "tokens=1-4 delims=/ " %%a in ('dir /tw /ad "%%~dpD" ^| findstr /c:" %%~nxD"') do (
        REM Tokens are: %%a=MM, %%b=DD, %%c=YYYY, %%d=time (e.g. "10:32")
        REM Some locales output DD/MM/YYYY - if your dates look wrong,
        REM swap %%a and %%b in the line below.
        set "FOLDER_DATE=%%c%%a%%b"
    )

    if not defined FOLDER_DATE (
        echo   [SKIP] Could not determine modified date for "%%~nxD"
    ) else (
        REM Compare folder date to cutoff (string compare works for YYYYMMDD)
        if !FOLDER_DATE! LSS %CUTOFF_YYYYMMDD% (
            echo   [SKIP] Folder last modified !FOLDER_DATE! ^(before cutoff^)
        ) else (
            REM Reset the "found" flag for each new folder
            set "FOUND_FILE="

            REM ------------------------------------------------
            REM  List files newest-first; first result wins
            REM ------------------------------------------------
            for /f "delims=" %%F in ('dir /b /a-d /o-d "%%D\*" 2^>nul') do (
                if not defined FOUND_FILE (
                    set "FOUND_FILE=%%D\%%F"
                )
            )

            if not defined FOUND_FILE (
                echo   [SKIP] No files found in "%%~nxD"
            ) else (
                call :CopyFile "!FOUND_FILE!"
            )
        )
    )
    echo.
)

echo ============================================================
echo  Done.
echo ============================================================
pause
exit /b 0


REM ============================================================
REM  Subroutine: CopyFile
REM  Copies the given file to DEST_DIR, renaming if a file
REM  with the same name already exists (e.g. file.txt -> file (1).txt)
REM ============================================================
:CopyFile
set "SRC_FILE=%~1"
set "FILE_NAME=%~nx1"
set "FILE_BASE=%~n1"
set "FILE_EXT=%~x1"

set "TARGET=%DEST_DIR%\%FILE_NAME%"
set /a COUNTER=1

REM If the target name already exists, append " (N)" until unique
:CheckName
if exist "%TARGET%" (
    set "TARGET=%DEST_DIR%\%FILE_BASE% (!COUNTER!)%FILE_EXT%"
    set /a COUNTER+=1
    goto CheckName
)

copy /y "%SRC_FILE%" "%TARGET%" >nul
if errorlevel 1 (
    echo   [ERROR] Failed to copy "%FILE_NAME%"
) else (
    echo   [COPY] "%FILE_NAME%" -^> "%TARGET%"
)
exit /b 0