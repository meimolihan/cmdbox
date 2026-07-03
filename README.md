# 命令收藏夹 (Command Box)

一个强大的命令行工具收藏与快速启动器，支持本地存储和 GitHub 云同步。

## 🌟 特性

- **快速执行**：输入数字直接执行命令，无需确认
- **智能搜索**：支持关键词搜索命令
- **云同步**：支持 GitHub 仓库同步，多设备共享
- **传参同步**：支持命令行传参快速同步
- **一键安装**：支持 curl 下载直接安装
- **导出连接**：导出当前配置为快速连接命令

## 🚀 快速开始

### 一键安装

```bash
bash <(curl -l -s https://raw.githubusercontent.com/byJoey/cmdbox/refs/heads/main/install.sh)
```

### 传参同步安装

```bash
bash <(curl -l -s https://raw.githubusercontent.com/byJoey/cmdbox/refs/heads/main/install.sh) --sync "用户名/仓库名" "GitHub_Token"
```

### 手动安装

```bash
# 下载脚本
wget https://raw.githubusercontent.com/byJoey/cmdbox/refs/heads/main/install.sh

# 添加执行权限
chmod +x install.sh

# 安装到系统
sudo cp install.sh /usr/local/bin/cb
sudo chmod +x /usr/local/bin/cb
```

## 📖 使用方法

### 启动命令收藏夹

```bash
cb
```

### 命令行选项

```bash
cb [选项]

选项:
  -h, --help     显示帮助信息
  -v, --version  显示版本信息
  -m, --manage   直接进入管理模式
  -s, --sync     手动同步到GitHub
  --sync <repo> <token>  传参同步到GitHub
  --reset        重置配置（重新选择模式）
```

### 传参同步示例

```bash
# 直接同步到GitHub
cb --sync "username/repo" "your_github_token"

# 一键安装并同步
bash <(curl -l -s https://raw.githubusercontent.com/byJoey/cmdbox/refs/heads/main/install.sh) --sync "username/repo" "your_github_token"
```

## 🔧 功能说明

### 主界面操作

- **数字键**：直接执行对应编号的命令
- **关键词**：搜索包含关键词的命令
- **01-06**：进入管理功能
- **0**：退出程序

### 管理功能

| 选项 | 功能 | 说明 |
|------|------|------|
| 01 | 添加命令 | 添加新的命令到收藏夹 |
| 02 | 编辑命令 | 修改现有命令的信息 |
| 03 | 删除命令 | 删除不需要的命令 |
| 04 | 同步管理 | 管理GitHub同步设置 |
| 05 | 配置设置 | 查看和修改配置 |
| 06 | 导入/导出 | 导入导出命令数据 |

### 同步模式

#### 本地模式
- 命令只保存在本地
- 简单快速，无需配置
- 适合单机使用

#### GitHub 同步模式
- 命令自动同步到GitHub
- 多设备共享命令库
- 需要GitHub仓库和Token

## 🔗 GitHub 同步配置

### 准备工作

1. **创建GitHub仓库**
   - 登录GitHub → 点击'+' → New repository
   - 仓库名建议: cmdbox-commands
   - 可设为Private保护隐私

2. **生成Personal Access Token**
   - 头像 → Settings → Developer settings
   - Personal access tokens → Tokens (classic)
   - Generate new token → 选择repo权限
   - **重要**: 复制生成的token（只显示一次）

### 配置步骤

1. 运行 `cb` 启动程序
2. 选择 `2` 进入GitHub同步模式
3. 输入仓库地址（格式: 用户名/仓库名）
4. 输入Personal Access Token
5. 测试连接成功后即可使用

### 导出快速连接

1. 进入配置设置（选项 05）
2. 选择导出快速连接（选项 3）
3. 复制输出的命令到新机器使用

## 📁 文件结构

```
~/.cmdbox/
├── config          # 配置文件
└── commands.json   # 命令数据文件
```

### 配置文件格式

```bash
SYNC_MODE=github
GITHUB_REPO="用户名/仓库名"
GITHUB_TOKEN="your_token"
```

### 命令数据格式

```json
{
  "commands": [
    {
      "id": 1234567890123,
      "name": "系统监控",
      "command": "htop",
      "description": "实时系统监控",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

## 🛠️ 依赖要求

- **bash**: 脚本运行环境
- **jq**: JSON 数据处理
- **curl**: HTTP 请求（GitHub API）
- **base64**: 数据编码

### 安装依赖

```bash
# Ubuntu/Debian
sudo apt install jq curl

# CentOS/RHEL
sudo yum install jq curl

# macOS
brew install jq curl
```

## 🔄 同步机制

### 自动同步
- 每次启动时自动从GitHub同步
- 如果是首次同步且仓库为空，显示"初始化成功！"
- 同步成功时显示"同步成功！"

### 手动同步
- 在同步管理中选择"同步到GitHub"
- 在同步管理中选择"从GitHub同步"

### 传参同步
- 支持命令行传参直接同步
- 格式：`cb --sync "仓库名" "Token"`

## 📝 使用示例

### 添加常用命令

```bash
# 启动程序
cb

# 选择 01 添加命令
# 输入命令名称：系统监控
# 输入命令内容：htop
# 输入描述：实时系统监控
```

### 搜索命令

```bash
# 在主界面输入关键词
# 例如：输入 "docker" 搜索相关命令
```

### 执行命令

```bash
# 直接输入数字执行命令
# 例如：输入 "1" 执行第一个命令
```

### 多设备同步

1. **设备A**：配置GitHub同步并添加命令
2. **导出连接**：在配置设置中导出快速连接
3. **设备B**：使用导出的命令快速同步

```bash
# 在设备B上执行导出的命令
bash <(curl -l -s https://raw.githubusercontent.com/byJoey/cmdbox/refs/heads/main/install.sh) --sync "username/repo" "your_github_token"
```

## 🔒 安全注意事项

- **Token 安全**：GitHub Token 包含敏感信息，请妥善保管
- **仓库权限**：建议使用私有仓库保护命令数据
- **网络环境**：确保网络环境安全，避免Token泄露

## 🐛 故障排除

### 常见问题

1. **jq 命令未找到**
   ```bash
   # 安装 jq
   sudo apt install jq  # Ubuntu/Debian
   brew install jq      # macOS
   ```

2. **GitHub 连接失败**
   - 检查仓库名和Token是否正确
   - 确认Token具有repo权限
   - 检查网络连接

3. **同步失败**
   - 检查GitHub配置是否完整
   - 确认仓库存在且有写入权限
   - 查看错误信息进行排查

### 重置配置

```bash
# 重置所有配置
cb --reset
```

## 📞 支持与反馈

- **GitHub**: [https://github.com/byjoey/cmdbox](https://github.com/byjoey/cmdbox)
- **博客**: [https://joeyblog.net](https://joeyblog.net)
- **Telegram**: [https://t.me/+ft-zI76oovgwNmRh](https://t.me/+ft-zI76oovgwNmRh)

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 📈 更新日志

### v1.0.3
- ✨ 新增传参同步功能
- ✨ 新增导出快速连接功能
- ✨ 优化每次启动自动同步
- 🐛 修复 base64 命令兼容性问题
- 🐛 修复命令行参数处理问题

### v1.0.2
- ✨ 新增 GitHub 云同步功能
- ✨ 新增搜索功能
- ✨ 优化用户界面

### v1.0.1
- ✨ 新增本地命令收藏功能
- ✨ 启用科技lion样式

### v1.0.0
- 🎉 初始版本发布
- ✨ 基础命令收藏功能

⭐ 如果这个项目对你有帮助，请给个Star支持一下！

## Star History

<a href="https://www.star-history.com/#byJoey/cmdbox&Timeline">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=byJoey/cmdbox&type=Timeline&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=byJoey/cmdbox&type=Timeline" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=byJoey/cmdbox&type=Timeline" />
 </picture>
</a>
