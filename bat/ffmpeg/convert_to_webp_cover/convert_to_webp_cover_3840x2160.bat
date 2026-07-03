@echo off
setlocal enabledelayedexpansion

if not exist "Completed_3840x2160" (
    mkdir "Completed_3840x2160"
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
        -vf "scale=3840:2160:force_original_aspect_ratio=increase,crop=3840:2160" ^
        -q:v 60 ^
        -compression_level 6 ^
        "Completed_3840x2160\%%~ni.webp"
)

pause
