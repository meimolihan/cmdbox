@echo off
setlocal enabledelayedexpansion

if not exist "Completed_1920x1080" (
    mkdir "Completed_1920x1080"
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
        -vf "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080" ^
        -q:v 60 ^
        -compression_level 6 ^
        "Completed_1920x1080\%%~ni.webp"
)

pause
