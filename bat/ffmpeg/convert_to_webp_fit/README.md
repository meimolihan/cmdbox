## 功能说明

将图片转换为 WebP 格式，并**等比缩放 + 填充黑边**到目标分辨率（fit 模式）。

**处理方式**：保持原图比例缩放，不足的部分用黑边填充。

**适用场景**：需要保持图片完整内容，且可接受黑边的情况。

## 下载批处理到 `下载目录`

- CMD 下载命令

```bash
cd /d "%USERPROFILE%\Downloads"
for %r in (320x180 640x360 960x540 1280x720 1920x1080 3840x2160 5120×2304) do curl.exe -L -o convert_to_webp_%r.bat https://gitee.com/meimolihan/cmdbox/raw/master/bat/ffmpeg/convert_to_webp_fit/convert_to_webp_%r.bat
```

- PowerShell 下载命令

```bash
cd ~\Downloads
$B="https://gitee.com/meimolihan/cmdbox/raw/master/bat/ffmpeg/convert_to_webp_fit"; "320x180","640x360","960x540","1280x720","1920x1080","3840x2160","5120x2304" | % { curl.exe -L -o "convert_to_webp_$_.bat" "$B/convert_to_webp_$_.bat" }
```

## 使用方法

1. 将批处理文件放到包含图片的目录
2. 双击运行对应的 `.bat` 文件
3. 转换后的 WebP 文件会保存到 `Completed_xxx×xxx` 文件夹

## 支持的输出分辨率

| 标称   | 分辨率        | 说明                     |
| ------- | ------------- | ------------------------ |
| 180p   | 320 × 180    | 最低可用 16:9           |
| 360p   | 640 × 360    | 低清网络视频            |
| 540p   | 960 × 540    | qHD                      |
| 720p   | 1280 × 720   | HD ✅                    |
| 1080p  | 1920 × 1080  | Full HD ✅               |
| 4K     | 3840 × 2160  | 4K UHD                  |
| 8K样片 | 5120 × 2304  | 特殊宽幅（非标准 16:9） |

## FFmpeg 参数说明

```bash
-vf "scale=W:H:force_original_aspect_ratio=decrease,pad=W:H:(ow-iw)/2:(oh-ih)/2"
```

- `force_original_aspect_ratio=decrease`：等比缩放，不超出目标区域
- `pad=W:H:(ow-iw)/2:(oh-ih)/2`：填充黑边到目标分辨率

## 三种模式对比

| 模式      | 是否保持比例 | 是否裁剪 | 是否加黑边 | 说明           |
| --------- | ------------ | -------- | ----------- | -------------- |
| **fit**   | ✅           | ❌       | ✅          | 等比 + 填充    |
| **cover** | ✅           | ✅       | ❌          | 等比 + 裁剪    |
| **stretch** | ❌          | ❌       | ❌          | 强制拉伸（变形） |
