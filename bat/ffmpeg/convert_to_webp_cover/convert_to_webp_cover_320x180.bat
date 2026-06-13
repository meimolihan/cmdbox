@echo off
setlocal enabledelayedexpansion

if not exist "Completed_320x180" (
    mkdir "Completed_320x180"
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
        -vf "scale=320:180:force_original_aspect_ratio=increase,crop=3840:2160" ^
        -q:v 60 ^
        -compression_level 6 ^
        "Completed_320x180\%%~ni.webp"
)

pause