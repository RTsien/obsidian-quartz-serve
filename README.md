# obsidian-quartz-serve

一键将 Obsidian vault 部署为 [Quartz v4](https://github.com/jackyzha0/quartz) 网页服务。

**把 `serve.sh` 丢进任意 Obsidian vault 根目录**，即可启动一个支持搜索、双链、图谱的静态网站，自带后台 `git pull` 自动同步最新笔记内容。

## 功能

- 🚀 自动初始化 Quartz（首次运行时 clone + npm install）
- 🔄 后台每 5 分钟 `git pull` 同步最新笔记内容
- 🌐 启动 HTTP 服务，支持搜索、双链跳转、知识图谱等 Obsidian 特性
- 🛠️ 内置 systemd 服务管理（一键安装 / 卸载 / 自动重启）

## 快速启动

```bash
# 把 serve.sh 复制到你的 Obsidian vault 根目录
cp serve.sh /path/to/your-vault/
cd /path/to/your-vault/

# 直接运行（默认端口 8080，监听 0.0.0.0）
chmod +x serve.sh
./serve.sh

# 指定对外地址（仅影响页面 meta 标签中的绝对 URL，不影响监听地址）
BASE_URL="10.0.0.1:8080" ./serve.sh
```

## 通过 systemd 管理（推荐服务器使用）

服务名根据目录名自动生成（`quartz-<目录名>`），也可通过 `--name` 指定。

```bash
# 安装并启动服务
sudo ./serve.sh install-service

# 安装时指定参数
sudo ./serve.sh install-service --base-url 10.0.0.1:8080 --port 8080

# 自定义服务名
sudo ./serve.sh install-service --name my-notes --base-url 10.0.0.1:3000 --port 3000

# 查看日志
sudo journalctl -u <服务名> -f  # 默认 quartz-<目录名>，或 --name 指定的名称

# 卸载服务
sudo ./serve.sh uninstall-service
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `SERVE_PORT` | `8080` | HTTP 服务监听端口 |
| `BASE_URL` | `localhost:$SERVE_PORT` | 页面 meta 标签中的绝对 URL（对外服务时建议设为实际 IP/域名） |
| `GIT_PULL_INTERVAL` | `300` | git pull 间隔（秒） |

## 前置依赖

- Node.js >= 20（推荐通过 nvm 安装）
- Git

## 工作原理

1. 首次运行时，自动 clone Quartz v4 到 `.quartz/` 并安装依赖
2. 自动维护 `.gitignore`，确保 `.quartz/`、`.service-name`、`node_modules/` 被排除
3. 根据环境变量生成 `quartz.config.ts`（中文字体、暗色主题等）
4. 后台启动 git pull 定时循环，保持笔记内容最新
5. 如果 vault 根目录缺少 `index.md`，自动创建默认首页
6. 前台启动 Quartz serve，自带文件 watch 自动重建

```
your-vault/
├── serve.sh          ← 本脚本
├── .quartz/          ← 自动生成，Quartz 运行时
├── .service-name     ← 自动生成，记录 systemd 服务名
├── index.md
├── notes/
│   ├── topic-a.md
│   └── topic-b.md
└── assets/
    └── images/
```

## 关于 `.service-name`

执行 `install-service` 时，脚本会在 vault 根目录写入 `.service-name` 文件，记录当前安装的 systemd 服务名。

- `uninstall-service` 会读取该文件自动找到对应服务并卸载，无需手动指定 `--name`
- 如果你手动删除了该文件，卸载时需要通过 `--name` 显式指定服务名

## License

MIT
