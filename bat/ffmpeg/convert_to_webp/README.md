## 功能说明

将图片无损转换为 WebP 格式

## 下载批处理到 `下载目录`

> 高质量压缩转换（-q:v 85，画质几乎无损）

- CMD 下载命令

```bash
cd /d "%USERPROFILE%\Downloads"
curl.exe -L -o https://gitee.com/meimolihan/cmdbox/raw/master/bat/ffmpeg/convert_to_webp/convert_to_webp.bat
```

- PowerShell 下载命令

```bash
cd ~\Downloads
curl.exe -L -o https://gitee.com/meimolihan/cmdbox/raw/master/bat/ffmpeg/convert_to_webp/convert_to_webp.bat
```

## 等价命令

- 高质量压缩转换（-q:v 85，画质几乎无损）

### 1. Windows CMD（单行等价命令）

```cmd
md Completed 2>nul && for %i in (*.dng *.DNG *.png *.PNG *.jpg *.JPG *.jpeg *.JPEG) do ffmpeg -i "%i" -y -q:v 85 -compression_level 6 "Completed\%~ni.webp"
```

### 2. Windows PowerShell（等价）

```bash
if (!(Test-Path "Completed")) { New-Item -ItemType Directory -Path "Completed" | Out-Null }
Get-ChildItem *.DNG, *.dng, *.png, *.PNG, *.jpg, *.JPG, *.jpeg, *.JPEG | % { ffmpeg -i $_.FullName -y -q:v 85 -compression_level 6 "Completed\$($_.BaseName).webp" }
```

### 3. Linux / macOS（Bash 等价）

```bash
mkdir -p Completed && for file in *.{dng,DNG,png,PNG,jpg,JPG,jpeg,JPEG}; do ffmpeg -i "$file" -y -q:v 85 -compression_level 6 "Completed/${file%.*}.webp"; done
```