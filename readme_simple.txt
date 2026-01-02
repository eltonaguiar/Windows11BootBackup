MIRACLE BOOT REPAIR - QUICK START
=================================

FAST RECOVERY:
1. Boot to Windows USB -> Repair -> Troubleshoot -> Command Prompt.
2. Run the automated fixer: G:\MIRACLE_BOOT_FIXER\miracle_boot_restore.cmd

MANUAL COMMANDS (IF SCRIPT FAILS):
-------------------------------------------
1. Mount EFI:        mountvol S: /S
2. Restore Files:    robocopy "G:\MIRACLE_BOOT_FIXER\<Date>\EFI" "S:\EFI" /MIR
3. Import BCD:       bcdedit /import "G:\MIRACLE_BOOT_FIXER\<Date>\BCD_EXPORT.bcd"
4. Refresh Boot:     bcdboot C:\Windows /s S: /f UEFI
5. Unmount:          mountvol S: /D