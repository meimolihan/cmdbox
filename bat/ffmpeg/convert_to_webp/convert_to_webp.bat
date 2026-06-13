@echo off
setlocal enabledelayedexpansion

if not exist "Completed" mkdir "Completed"

for %%i in (
    *.dng *.DNG
    *.png *.PNG
    *.jpg *.JPG
    *.jpeg *.JPEG
) do (
    echo Processing: %%~nxi
    ffmpeg -i "%%i" -y -q:v 85 -compression_level 6 "Completed\%%~ni.webp"
)

pause