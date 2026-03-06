@echo off
setlocal
cd /d "%~dp0"
echo Hosting resource packs from: %cd%\resourcepacks
echo URL base: http://^<server-ip^>:8080/
echo Press Ctrl+C to stop.
node "%~dp0start-resourcepack-host.js"
