@echo off
setlocal enabledelayedexpansion

if not exist "Completed_640x360" (
    mkdir "Completed_640x360"
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
        -vf "scale=640:360:force_original_aspect_ratio=increase,crop=640:360" ^
        -q:v 60 ^
        -compression_level 6 ^
        "Completed_640x360\%%~ni.webp"
)

pause
