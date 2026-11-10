@echo off
chcp 65001 > nul
echo ========================================================
echo  말랑이의 말하기 탐험대 웹 서버를 시작합니다...
echo ========================================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0server.ps1"
pause
