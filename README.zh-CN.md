# obsidian-quartz-serve

[English](README.md) | 简体中文

一键将任意 Obsidian vault 部署为 [Quartz v4](https://github.com/jackyzha0/quartz) 网站。

**把 `serve.sh` 放进 Obsidian vault 根目录**，即可启动一个支持搜索、双链和图谱的静态网站。后台 `git pull` 循环会自动同步最新笔记内容。

## 功能

- 🚀 首次运行时自动初始化 Quartz（`git clone` + `npm install`）
- 🔄 每五分钟在后台通过 `git pull` 同步最新笔记
- 🌐 提供支持搜索、双链和知识图谱的网站
- 🛠️ 内置 systemd 服务管理，支持一键安装、卸载和自动重启

## 快速开始

```bash
# 把 serve.sh 复制到 Obsidian vault 根目录
cp serve.sh /path/to/your-vault/
cd /path/to/your-vault/

# 直接运行（默认监听 0.0.0.0:8080）
chmod +x serve.sh
./serve.sh

# 指定页面元数据中绝对 URL 使用的对外地址。
# 此设置不会改变监听地址。
BASE_URL="10.0.0.1:8080" ./serve.sh
```

## 使用 systemd 管理服务

推荐用于服务器部署。服务名会根据 vault 目录名自动生成为 `quartz-<目录名>`，也可通过 `--name` 自定义。

```bash
# 安装并启动服务
sudo ./serve.sh install-service

# 安装时指定参数
sudo ./serve.sh install-service --base-url 10.0.0.1:8080 --port 8080

# 自定义服务名
sudo ./serve.sh install-service --name my-notes --base-url 10.0.0.1:3000 --port 3000

# 查看日志
sudo journalctl -u <服务名> -f  # 默认为 quartz-<目录名>

# 卸载服务
sudo ./serve.sh uninstall-service
```

## 环境变量

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `SERVE_PORT` | `8080` | HTTP 服务监听端口 |
| `BASE_URL` | `localhost:$SERVE_PORT` | 页面元数据中绝对 URL 使用的对外地址；公开部署时建议设置为实际 IP 地址或域名 |
| `GIT_PULL_INTERVAL` | `300` | `git pull` 执行间隔，单位为秒 |

## 前置依赖

- Node.js 20 或更高版本（推荐通过 nvm 安装）
- Git
- systemd（仅使用服务管理命令时需要）

## 工作原理

1. 首次运行时，脚本自动将 Quartz v4 克隆到 `.quartz/` 并安装依赖。
2. 自动维护 `.gitignore`，确保 `.quartz/`、`.service-name` 和 `node_modules/` 被排除。
3. 根据环境变量生成 `quartz.config.ts`，并配置简体中文字体和暗色主题。
4. 在后台启动 `git pull` 定时循环，保持 vault 内容最新。
5. 如果 vault 根目录缺少 `index.md`，自动创建默认首页。
6. 启动带文件监听和自动重建功能的 Quartz 开发服务器。

```text
your-vault/
├── serve.sh          # 本脚本
├── .quartz/          # 自动生成的 Quartz 运行时
├── .service-name     # 自动生成的 systemd 服务名记录
├── index.md
├── notes/
│   ├── topic-a.md
│   └── topic-b.md
└── assets/
    └── images/
```

## 关于 `.service-name`

执行 `install-service` 时，脚本会在 vault 根目录写入 `.service-name`，记录已安装的 systemd 服务名。

- `uninstall-service` 会读取该文件并自动找到对应服务，无需再次传入 `--name`。
- 如果手动删除了该文件，卸载时需要通过 `--name` 显式指定服务名。

## 许可证

MIT
