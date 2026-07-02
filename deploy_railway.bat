@echo off
REM ==============================================================================
REM   ZEDTUNNEL PRO | Windows Deployment Command Wrapper
REM ==============================================================================
powershell -ExecutionPolicy Bypass -File "%~dp0deploy_railway.ps1"
pause
