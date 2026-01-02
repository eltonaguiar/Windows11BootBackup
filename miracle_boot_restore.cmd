@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo ======================================================
echo    MIRACLE BOOT RESTORE - AUTOMATED RECOVERY
echo ======================================================

REM --- Safety Check: Find Windows ---
set "WIN_DRIVE="
for %%D in (C D E F G H I) do (
    if exist "%%D:\Windows\System32\config\SYSTEM" (
        set "WIN_DRIVE=%%D:"
        echo [OK] Windows installation found on !WIN_DRIVE!
        goto :found_win
    )
)

:found_win
if "%WIN_DRIVE%"=="" (
    echo [ERROR] No Windows installation detected. Is the drive encrypted?
    pause & exit /b 1
)

REM --- Setup Mount Point ---
set "MNT=S:"
mountvol %MNT% /D >nul 2>&1
if exist %MNT%\ ( set "MNT=Z:" )

REM --- Gather top 3 recent backups ---
echo [INFO] Searching for the 3 most recent backups...
set "count=0"
for /f "delims=" %%D in ('dir /b /ad /o-n "G:\MIRACLE_BOOT_FIXER" ^| findstr /r "^20[0-9][0-9]-"') do (
    set /a count+=1
    set "backup[!count!]=%%D"
    if !count! equ 3 goto :found_backups
)
:found_backups

if %count% equ 0 (
    echo [ERROR] No backup folders found.
    pause & exit /b 1
)

REM --- Restore Loop ---
for /l %%i in (1,1,%count%) do (
    set "CURRENT_BACKUP=!backup[%%i]!"
    set "BACKUP_PATH=G:\MIRACLE_BOOT_FIXER\!CURRENT_BACKUP!"
    
    echo.
    echo ------------------------------------------------------
    echo  ATTEMPT %%i: !CURRENT_BACKUP!
    echo ------------------------------------------------------
    
    REM 1. Mount EFI [cite: 7]
    mountvol %MNT% /S >nul 2>&1
    if not exist %MNT%\ (
        echo [ERROR] Could not mount EFI partition.
        goto :next_attempt
    )

    REM 2. Restore EFI Files [cite: 7]
    echo [INFO] Restoring EFI files...
    robocopy "!BACKUP_PATH!\EFI" "%MNT%\EFI" /MIR /B /R:1 /W:1 >nul
    
    REM 3. Restore BCD [cite: 7]
    echo [INFO] Importing BCD Store...
    bcdedit /import "!BACKUP_PATH!\BCD_EXPORT.bcd" >nul 2>&1
    
    REM 4. Rebuild Bootloader [cite: 7]
    echo [INFO] Rebuilding bootloader for !WIN_DRIVE!...
    bcdboot !WIN_DRIVE!\Windows /s %MNT% /f UEFI >nul 2>&1
    
    if %errorlevel% equ 0 (
        echo [SUCCESS] Boot files restored from !CURRENT_BACKUP!.
        
        REM Driver Injection Option [cite: 2]
        set /p "inject=Inject backup drivers? (y/n) [Recommended for 0x7B errors]: "
        if /i "!inject!"=="y" (
            echo [INFO] Injecting drivers into !WIN_DRIVE!...
            dism /Image:!WIN_DRIVE!\ /Add-Driver /Driver:"!BACKUP_PATH!\DRIVERS" /Recurse
        )

        mountvol %MNT% /D >nul 2>&1
        echo [DONE] You may now restart your PC. [cite: 13]
        pause & exit /b 0
    )

    :next_attempt
    mountvol %MNT% /D >nul 2>&1
)

echo.
echo [FATAL] All available backups failed to restore.
pause
exit /b 1