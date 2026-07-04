@echo off
setlocal enabledelayedexpansion

if not exist "Completed_1280x720" (
    mkdir "Completed_1280x720"
)

for %%i in (
    *.WEBP *.webp
    *.dng *.DNG
    *.png *.PNG
    *.jpg *.JPG
    *.jpeg *.JPEG
) do (
    echo Processing: %%~nxi
    ffmpeg -i "%%i" ^
        -y ^
        -vf "scale=1280:720" ^
        -q:v 60 ^
        -compression_level 6 ^
        "Completed_1280x720\%%~ni.webp"
)

pause
