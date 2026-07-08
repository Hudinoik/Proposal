@echo off
title TCO Agreement Generator
setlocal
set "DIR=%~dp0"
set "APP=%DIR%index.html"
if not exist "%APP%" (
  echo Could not find index.html next to this launcher.
  echo Keep this file in the same folder as index.html.
  pause
  exit /b 1
)
set "URL=file:///%APP:\=/%"

rem Open in an app-style window (no tabs / address bar). Edge is on every Windows PC.
set "EDGE=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not exist "%EDGE%" set "EDGE=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
if exist "%EDGE%" (
  start "" "%EDGE%" --app="%URL%"
  exit /b 0
)

set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%LocalAppData%\Google\Chrome\Application\chrome.exe"
if exist "%CHROME%" (
  start "" "%CHROME%" --app="%URL%"
  exit /b 0
)

rem Fall back to the default browser
start "" "%APP%"
