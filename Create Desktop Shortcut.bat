@echo off
title Create Desktop Shortcut - TCO Agreement Generator
powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=Split-Path -Parent '%~f0'; $ws=New-Object -ComObject WScript.Shell; $lnk=[IO.Path]::Combine([Environment]::GetFolderPath('Desktop'),'TCO Agreement Generator.lnk'); $s=$ws.CreateShortcut($lnk); $s.TargetPath=[IO.Path]::Combine($d,'TCO Agreement Generator.bat'); $s.WorkingDirectory=$d; $s.IconLocation=([IO.Path]::Combine($d,'tco.ico')+',0'); $s.Description='TCO Agreement Generator'; $s.Save(); Write-Host ''; Write-Host 'Done! A TCO Agreement Generator shortcut is now on your Desktop.'"
pause
