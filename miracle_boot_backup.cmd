@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ======================================================
REM MIRACLE BOOT BACKUP (UEFI + Legacy + Drivers)
REM Output: G:\MIRACLE_BOOT_FIXER\<timestamp>\
REM ======================================================

REM --- Require admin ---
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo [ERROR] Run this as Administrator.
    pause
    exit /b 1
)

REM --- Destination root ---
set "DESTROOT=G:\MIRACLE_BOOT_FIXER"
if not exist "G:\" (
    echo [ERROR] G: drive not found.
    pause
    exit /b 1
)

REM --- Timestamp ---
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'"') do set "TS=%%I"
set "OUT=%DESTROOT%\%TS%"
set "LOGS=%OUT%\LOGS"
set "DRIVERS=%OUT%\DRIVERS"
mkdir "%LOGS%" 2>nul
mkdir "%DRIVERS%" 2>nul

echo [OK] Output folder: "%OUT%"

REM --- Detect Boot Mode ---
set "BOOT_MODE=LEGACY"
bcdedit | find /i "winload.efi" >nul && set "BOOT_MODE=UEFI" [cite: 15]

echo [INFO] Detected Boot Mode: %BOOT_MODE%

if "%BOOT_MODE%"=="UEFI" (
    call :BACKUP_UEFI
) else (
    call :BACKUP_LEGACY
)

REM --- Driver Store Backup ---
echo [INFO] Exporting 3rd-party drivers (Storage/Chipset)...
pnputil /export-driver * "%DRIVERS%" > "%LOGS%\driver_export.txt" 2>&1

REM --- Common Tasks (BCD & Layout) ---
echo [INFO] Exporting BCD store...
bcdedit /export "%OUT%\BCD_EXPORT.bcd" > "%LOGS%\bcd_export.txt" 2>&1 [cite: 16]
bcdedit /enum all > "%OUT%\BCD_ENUM_ALL.txt" 2>&1 [cite: 16]

echo [INFO] Saving disk layout...
(echo list disk & echo list volume & echo list partition) > "%LOGS%\layout_cmd.txt"
diskpart /s "%LOGS%\layout_cmd.txt" > "%OUT%\DISK_LAYOUT.txt" 2>&1 [cite: 16]

REM --- Cleanup: Keep only last 10 backups ---
echo [INFO] Cleaning up old backups (keeping last 10)...
set "count=0"
for /f "skip=10 delims=" %%A in ('dir "%DESTROOT%" /b /ad /o-n /tc') do (
    echo [DELETE] Removing old backup: %%A
    rd /s /q "%DESTROOT%\%%A"
)

echo.
echo [DONE] Backup saved to %OUT% [cite: 16]
pause
exit /b 0

:BACKUP_UEFI
    set "MNT="
    for %%L in (T U V W X Y Z) do (if not exist %%L:\ set "MNT=%%L" & goto :found_uefi_letter)
    :found_uefi_letter
    echo [INFO] Mounting EFI to %MNT%: ... [cite: 17]
    mountvol %MNT%: /S > "%LOGS%\mountvol.txt" 2>&1 [cite: 17]
    
    echo [INFO] Copying EFI files... [cite: 17]
    robocopy "%MNT%:\EFI" "%OUT%\EFI" /MIR /B /R:3 /W:5 /XJ /FFT /COPY:DAT /DCOPY:DAT > "%LOGS%\robocopy_efi.txt" [cite: 17]
    
    mountvol %MNT%: /D >nul [cite: 17]
    goto :eof

:BACKUP_LEGACY [cite: 18]
    echo [INFO] Checking for hidden System Reserved partition...
    set "MNT="
    for %%L in (T U V W X Y Z) do (if not exist %%L:\ set "MNT=%%L" & goto :found_legacy_letter)
    :found_legacy_letter

    if exist "C:\Boot" ( [cite: 19]
        echo [INFO] Boot folder found on C:. Copying... [cite: 19]
        robocopy "C:\Boot" "%OUT%\Boot" /MIR /B /R:3 /W:5 /XJ /FFT /COPY:DAT /DCOPY:DAT > "%LOGS%\robocopy_boot.txt" [cite: 19]
    ) else ( [cite: 20]
        echo [INFO] Attempting to mount System Reserved... [cite: 20]
        powershell -NoProfile -Command "$v = Get-Volume | Where-Object { $_.IsActive -eq $true -or $_.FileSystemLabel -match 'System' }; if ($v) { Set-Partition -DriveLetter %MNT% -InputObject (Get-Partition -DriveLetter $v.DriveLetter) } else { exit 1 }" [cite: 20]
        
        if exist %MNT%:\Boot ( [cite: 20]
            robocopy "%MNT%:\Boot" "%OUT%\Boot" /MIR /B /R:3 /W:5 /XJ /FFT /COPY:DAT /DCOPY:DAT > "%LOGS%\robocopy_boot_hidden.txt" [cite: 20]
            mountvol %MNT%: /D >nul [cite: 20]
        )
    )
    goto :eof