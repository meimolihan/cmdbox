@echo off
setlocal enabledelayedexpansion

if not exist "Completed_5120x2304" (
    mkdir "Completed_5120x2304"
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
        -vf "scale=5120:2304:force_original_aspect_ratio=increase,crop=5120:2304" ^
        -q:v 60 ^
        -compression_level 6 ^
        "Completed_5120x2304\%%~ni.webp"
)

pause
