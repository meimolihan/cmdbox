@echo off
setlocal enabledelayedexpansion

if not exist "Completed_960x540" (
    mkdir "Completed_960x540"
)

for %%i in (*.WEBP, *.webp, *.dng *.DNG *.png *.PNG *.jpg *.JPG *.jpeg *.JPEG) do (
    echo Processing: %%~nxi
    ffmpeg -i "%%i" ^
        -y ^
        -vf "scale=960:540:force_original_aspect_ratio=decrease,pad=960:540:(ow-iw)/2:(oh-ih)/2" ^
        -q:v 60 ^
        -compression_level 6 ^
        "Completed_960x540\%%~ni.webp"
)

pause