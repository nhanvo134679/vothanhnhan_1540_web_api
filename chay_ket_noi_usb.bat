@echo off
chcp 65001 >nul
title KET NOI CAP USB WEB API 5104 - VO THANH NHAN
echo ========================================================
echo   DANG KET NOI CAP USB VA CHUYEN TIEP CONG 5104 (ADB)
echo ========================================================
echo.

set ADB_PATH="%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"

if exist %ADB_PATH% (
    %ADB_PATH% reverse tcp:5104 tcp:5104
    if %ERRORLEVEL% EQU 0 (
        echo [THANH CONG] Da dao cong thanh cong: Dien thoai da co the truy cap http://localhost:5104 hoac http://127.0.0.1:5104
    ) else (
        echo [CHU Y] Vui long kiem tra: Dien thoai da bat "Go loi USB (USB Debugging)" chua?
    )
) else (
    adb reverse tcp:5104 tcp:5104
)

echo.
echo ========================================================
echo   DANH SACH THIET BI DANG KET NOI:
%ADB_PATH% devices
echo ========================================================
echo.
pause
