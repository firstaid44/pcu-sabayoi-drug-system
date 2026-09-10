@echo off
chcp 65001 >nul
title EA Dashboard v6.0 - XAUUSD
cd /d "%~dp0"
rem  เปลี่ยนฟอนต์ได้ที่บรรทัดล่าง: plex | prompt | anuphan | noto | sarabun | kanit | niramit
set FONT=plex
rem  เลขบัญชีที่จะโชว์บนหน้า Home (เว้นว่าง = ใช้จาก PosExport อัตโนมัติ)
set ACCOUNT=
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-dashboard.ps1" -Font %FONT% -Account "%ACCOUNT%"
echo.
echo [ หยุดทำงานแล้ว - กดปุ่มใดๆ เพื่อปิด ]
pause >nul
