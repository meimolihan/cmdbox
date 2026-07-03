## 功能说明

将图片转换为 WebP 格式，并**裁剪**到目标分辨率（cover 模式）。

**处理方式**：等比缩放图片使其**覆盖**整个目标区域，然后**裁剪**溢出的部分。

**适用场景**：需要严格固定分辨率，且不介意部分内容被裁剪的情况。

## 下载批处理到 `下载目录`

- CMD 下载命令

```bash
cd /d "%USERPROFILE%\Downloads"
for %r in (320x180 640x360 960x540 1280x720 1920x1080 3840x2160 5120x2304) do curl.exe -L -o convert_to_webp_cover_%r.bat https://gitee.com/meimolihan/cmdbox/raw/master/bat/ffmpeg/convert_to_webp_cover/convert_to_webp_cover_%r.bat
```

- PowerShell 下载命令

```bash
cd ~\Downloads
$B="https://gitee.com/meimolihan/cmdbox/raw/master/bat/ffmpeg/convert_to_webp_cover"; "320x180","640x360","960x540","1280x720","1920x1080","3840x2160","5120x2304" | % { curl.exe -L -o "convert_to_webp_cover_$_.bat" "$B/convert_to_webp_cover_$_.bat" }
```

## 使用方法

1. 将批处理文件放到包含图片的目录
2. 双击运行对应的 `.bat` 文件
3. 转换后的 WebP 文件会保存到 `Completed_xxx×xxx` 文件夹

## 支持的输出分辨率

| 标称   | 分辨率        | 说明                     |
| ------ | ------------- | ------------------------ |
| 180p   | 320 × 180    | 最低可用 16:9           |
| 360p   | 640 × 360    | 低清网络视频            |
| 540p   | 960 × 540    | qHD                      |
| 720p   | 1280 × 720   | HD ✅                    |
| 1080p  | 1920 × 1080  | Full HD ✅               |
| 4K     | 3840 × 2160  | 4K UHD                  |
| 8K样片 | 5120 × 2304  | 特殊宽幅（非标准 16:9） |

## FFmpeg 参数说明

```bash
-vf "scale=W:H:force_original_aspect_ratio=increase,crop=W:H"
```

- `force_original_aspect_ratio=increase`：等比缩放直到覆盖目标区域
- `crop=W:H`：裁剪到精确的目标分辨率

## 三种模式对比

| 模式      | 是否保持比例 | 是否裁剪 | 是否加黑边 | 说明           |
| --------- | ------------ | -------- | ----------- | -------------- |
| **fit**   | ✅           | ❌       | ✅          | 等比 + 填充    |
| **cover** | ✅           | ✅       | ❌          | 等比 + 裁剪    |
| **stretch** | ❌          | ❌       | ❌          | 强制拉伸（变形） |
