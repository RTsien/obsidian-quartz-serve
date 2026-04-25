#!/usr/bin/env bash
# serve.sh — 一键部署 Obsidian 笔记为 Quartz 网页服务
#
# 功能：
#   1. 自动初始化 Quartz v4（如果 .quartz/ 不存在）
#   2. 后台每 5 分钟 git pull 同步笔记内容
#   3. 前台启动 Quartz 服务（端口 8080，自带文件 watch 自动重建）
#
# 用法：
#   chmod +x serve.sh
#   ./serve.sh                                          # 直接运行
#   BASE_URL="10.0.0.1:8080" ./serve.sh                 # 指定对外地址
#   ./serve.sh install-service                           # 安装 systemd 服务
#   ./serve.sh install-service --base-url 10.0.0.1:8080  # 安装时指定参数
#   ./serve.sh uninstall-service                         # 卸载 systemd 服务

set -euo pipefail

# ============================================================
# 配置
# ============================================================
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
QUARTZ_DIR="${REPO_DIR}/.quartz"
QUARTZ_REPO="https://github.com/jackyzha0/quartz.git"
QUARTZ_BRANCH="v4"
SERVE_PORT="${SERVE_PORT:-8080}"
BASE_URL="${BASE_URL:-localhost:${SERVE_PORT}}"  # 用于 meta 标签中的绝对 URL
GIT_PULL_INTERVAL="${GIT_PULL_INTERVAL:-300}"  # 秒，默认 5 分钟

# 服务名根据目录名动态生成：quartz-<目录名>
SERVICE_NAME="quartz-$(basename "$REPO_DIR")"

# ============================================================
# 日志工具
# ============================================================
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ============================================================
# 信号处理：清理后台进程
# ============================================================
GIT_PULL_PID=""

cleanup() {
    log "收到退出信号，正在清理..."
    if [[ -n "$GIT_PULL_PID" ]] && kill -0 "$GIT_PULL_PID" 2>/dev/null; then
        kill "$GIT_PULL_PID" 2>/dev/null || true
        wait "$GIT_PULL_PID" 2>/dev/null || true
    fi
    log "清理完成，退出"
    exit 0
}

trap cleanup SIGTERM SIGINT SIGHUP

# ============================================================
# 步骤 1：初始化 Quartz
# ============================================================
init_quartz() {
    if [[ -d "$QUARTZ_DIR" && -f "$QUARTZ_DIR/package.json" ]]; then
        log "Quartz 已存在，跳过克隆"
    else
        log "正在克隆 Quartz v4..."
        git clone --depth 1 --branch "$QUARTZ_BRANCH" "$QUARTZ_REPO" "$QUARTZ_DIR"

        log "正在安装 Quartz 依赖..."
        cd "$QUARTZ_DIR"
        npm install

        # 删除 Quartz 自带的示例 content 目录（使用 --directory 参数指向仓库根目录）
        rm -rf "${QUARTZ_DIR}/content"
    fi

    # 每次启动都重写配置（BASE_URL 等可能变化）
    log "写入 Quartz 配置..."
    write_quartz_config



    # 确保 .gitignore 包含必要的排除项
    local gi="${REPO_DIR}/.gitignore"
    local entries=(".quartz/" ".service-name" "node_modules/")
    for entry in "${entries[@]}"; do
        if [[ ! -f "$gi" ]] || ! grep -qxF "$entry" "$gi"; then
            echo "$entry" >> "$gi"
            log "已添加 $entry 到 .gitignore"
        fi
    done

    # 如果 vault 根目录没有 index.md，创建一个默认的
    if [[ ! -f "${REPO_DIR}/index.md" ]]; then
        log "未检测到 index.md，创建默认首页..."
        cat > "${REPO_DIR}/index.md" << INDEX_EOF
# Welcome

> 由 [Quartz](https://quartz.jzhao.xyz/) 驱动的笔记站点。
INDEX_EOF
    fi
    cd "$REPO_DIR"
    log "Quartz 初始化完成"
}

write_quartz_config() {
    cat > "${QUARTZ_DIR}/quartz.config.ts" << QUARTZ_CONFIG
import { QuartzConfig } from "./quartz/cfg"
import * as Plugin from "./quartz/plugins"

const config: QuartzConfig = {
  configuration: {
    pageTitle: "My Notes",
    pageTitleSuffix: "",
    enableSPA: true,
    enablePopovers: true,
    analytics: null,
    locale: "zh-CN",
    baseUrl: "${BASE_URL}",
    ignorePatterns: [
      ".quartz",
      ".git",
      ".obsidian",
      ".workbuddy",
      "node_modules",
      "Intermediate",
      "Binaries",
      "DerivedDataCache",
      "Saved",
      "*.uproject",
      "*.uasset",
      "*.umap",
      "*.target",
      "*.dll",
      "*.exe",
      "*.pdb",
      "*.o",
      "*.obj",
    ],
    defaultDateType: "modified",
    theme: {
      fontOrigin: "googleFonts",
      cdnCaching: true,
      typography: {
        header: "Noto Sans SC",
        body: "Noto Sans SC",
        code: "JetBrains Mono",
      },
      colors: {
        lightMode: {
          light: "#faf8f8",
          lightgray: "#e5e5e5",
          gray: "#b8b8b8",
          darkgray: "#4e4e4e",
          dark: "#2b2b2b",
          secondary: "#284b63",
          tertiary: "#84a59d",
          highlight: "rgba(143, 159, 169, 0.15)",
          textHighlight: "#fff23688",
        },
        darkMode: {
          light: "#161618",
          lightgray: "#393639",
          gray: "#646464",
          darkgray: "#d4d4d4",
          dark: "#ebebec",
          secondary: "#7b97aa",
          tertiary: "#84a59d",
          highlight: "rgba(143, 159, 169, 0.15)",
          textHighlight: "#fff23688",
        },
      },
    },
  },
  plugins: {
    transformers: [
      Plugin.FrontMatter(),
      Plugin.CreatedModifiedDate({ priority: ["git", "filesystem"] }),
      Plugin.SyntaxHighlighting({ theme: { light: "github-light", dark: "github-dark" } }),
      Plugin.ObsidianFlavoredMarkdown({ enableInHtmlEmbed: false }),
      Plugin.GitHubFlavoredMarkdown(),
      Plugin.TableOfContents(),
      Plugin.CrawlLinks({ markdownLinkResolution: "shortest" }),
      Plugin.Description(),
      Plugin.Latex({ renderEngine: "katex" }),
    ],
    filters: [Plugin.RemoveDrafts()],
    emitters: [
      Plugin.AliasRedirects(),
      Plugin.ComponentResources(),
      Plugin.ContentPage(),
      Plugin.FolderPage(),
      Plugin.TagPage(),
      Plugin.ContentIndex({ enableSiteMap: true, enableRSS: true }),
      Plugin.Assets(),
      Plugin.Static(),
      Plugin.NotFoundPage(),
    ],
  },
}

export default config
QUARTZ_CONFIG
}

# ============================================================
# 步骤 2：后台 git pull 定时循环
# ============================================================
start_git_pull_loop() {
    log "启动 git pull 定时循环（间隔 ${GIT_PULL_INTERVAL} 秒）"
    (
        while true; do
            sleep "$GIT_PULL_INTERVAL"
            log "[git-pull] 正在拉取最新内容..."


    # 确保 .gitignore 包含必要的排除项
    local gi="${REPO_DIR}/.gitignore"
    local entries=(".quartz/" ".service-name" "node_modules/")
    for entry in "${entries[@]}"; do
        if [[ ! -f "$gi" ]] || ! grep -qxF "$entry" "$gi"; then
            echo "$entry" >> "$gi"
            log "已添加 $entry 到 .gitignore"
        fi
    done

    # 如果 vault 根目录没有 index.md，创建一个默认的
    if [[ ! -f "${REPO_DIR}/index.md" ]]; then
        log "未检测到 index.md，创建默认首页..."
        cat > "${REPO_DIR}/index.md" << INDEX_EOF
# Welcome

> 由 [Quartz](https://quartz.jzhao.xyz/) 驱动的笔记站点。
INDEX_EOF
    fi
            cd "$REPO_DIR"
            if git pull --ff-only 2>&1; then
                log "[git-pull] 拉取完成"
            else
                log "[git-pull] 拉取失败（可能有本地修改或网络问题）"
            fi
        done
    ) &
    GIT_PULL_PID=$!
    log "git pull 后台进程 PID: $GIT_PULL_PID"
}

# ============================================================
# 步骤 3：启动 Quartz 服务
# ============================================================
start_quartz_serve() {
    log "启动 Quartz 服务（端口 ${SERVE_PORT}）..."
    cd "$QUARTZ_DIR"
    npx quartz build --serve --port "$SERVE_PORT" --directory "$REPO_DIR"
}

# ============================================================
# install-service：生成并安装 systemd 服务
# ============================================================
cmd_install_service() {
    # 解析 install-service 的参数
    local svc_base_url=""
    local svc_port=""
    local svc_interval=""
    local svc_name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --base-url)  svc_base_url="$2";  shift 2 ;;
            --port)      svc_port="$2";       shift 2 ;;
            --interval)  svc_interval="$2";   shift 2 ;;
            --name)      svc_name="$2";       shift 2 ;;
            *) echo "未知参数: $1"; echo "用法: $0 install-service [--name NAME] [--base-url URL] [--port PORT] [--interval SECONDS]"; exit 1 ;;
        esac
    done

    local final_name="${svc_name:-$SERVICE_NAME}"
    local service_file="/etc/systemd/system/${final_name}.service"
    local node_bin
    node_bin="$(dirname "$(which node)")"

    # 构建 Environment 行
    local env_lines="Environment=PATH=${node_bin}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    env_lines+="\nEnvironment=NODE_ENV=production"
    [[ -n "$svc_port" ]]     && env_lines+="\nEnvironment=SERVE_PORT=${svc_port}"
    [[ -n "$svc_base_url" ]] && env_lines+="\nEnvironment=BASE_URL=${svc_base_url}"
    [[ -n "$svc_interval" ]] && env_lines+="\nEnvironment=GIT_PULL_INTERVAL=${svc_interval}"

    log "生成 systemd 服务: ${final_name}"
    cat > "/tmp/${final_name}.service" << EOF
# ${final_name}.service — 由 serve.sh install-service 自动生成
[Unit]
Description=Quartz 笔记网页服务 (${final_name})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${REPO_DIR}
$(echo -e "$env_lines")
ExecStart=/bin/bash ${REPO_DIR}/serve.sh
KillMode=control-group
KillSignal=SIGTERM
TimeoutStopSec=30
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${final_name}

[Install]
WantedBy=multi-user.target
EOF

    sudo cp "/tmp/${final_name}.service" "$service_file"
    rm -f "/tmp/${final_name}.service"
    sudo systemctl daemon-reload
    # 记录服务名，供 uninstall-service 自动识别
    echo "${final_name}" > "${REPO_DIR}/.service-name"

    sudo systemctl enable --now "${final_name}"

    log "服务已安装并启动: ${final_name}"
    echo ""
    echo "常用命令："
    echo "  sudo systemctl status  ${final_name}   # 查看状态"
    echo "  sudo journalctl -u ${final_name} -f     # 查看日志"
    echo "  sudo systemctl restart ${final_name}    # 重启服务"
    echo "  sudo systemctl stop    ${final_name}    # 停止服务"
    echo "  $0 uninstall-service                     # 卸载服务"
}

# ============================================================
# uninstall-service：卸载 systemd 服务
# ============================================================
cmd_uninstall_service() {
    local svc_name=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) svc_name="$2"; shift 2 ;;
            *) echo "未知参数: $1"; echo "用法: $0 uninstall-service [--name NAME]"; exit 1 ;;
        esac
    done

    # 优先用参数，其次读 .service-name，最后用默认名
    local final_name
    if [[ -n "$svc_name" ]]; then
        final_name="$svc_name"
    elif [[ -f "${REPO_DIR}/.service-name" ]]; then
        final_name="$(cat "${REPO_DIR}/.service-name")"
    else
        final_name="$SERVICE_NAME"
    fi
    local service_file="/etc/systemd/system/${final_name}.service"

    if [[ ! -f "$service_file" ]]; then
        echo "服务 ${final_name} 不存在: ${service_file}"
        exit 1
    fi

    log "停止并卸载服务: ${final_name}"
    sudo systemctl stop "${final_name}" 2>/dev/null || true
    sudo systemctl disable "${final_name}" 2>/dev/null || true
    sudo rm -f "$service_file"
    sudo systemctl daemon-reload
    rm -f "${REPO_DIR}/.service-name"

    log "服务已卸载: ${final_name}"
}

# ============================================================
# 主流程
# ============================================================
main() {
    log "========================================"
    log "Obsidian Quartz 笔记服务"
    log "仓库目录: $REPO_DIR"
    log "Quartz 目录: $QUARTZ_DIR"
    log "服务端口: $SERVE_PORT"
    log "Base URL: $BASE_URL"
    log "Git Pull 间隔: ${GIT_PULL_INTERVAL}s"
    log "========================================"

    init_quartz
    start_git_pull_loop
    start_quartz_serve
}

# ============================================================
# 命令分发
# ============================================================
case "${1:-}" in
    install-service)
        shift
        cmd_install_service "$@"
        ;;
    uninstall-service)
        shift
        cmd_uninstall_service "$@"
        ;;
    ""|serve)
        main
        ;;
    *)
        echo "用法: $0 [serve|install-service|uninstall-service]"
        echo ""
        echo "命令："
        echo "  serve              启动服务（默认）"
        echo "  install-service    安装 systemd 服务"
        echo "    --name NAME        服务名（默认: ${SERVICE_NAME}）"
        echo "    --base-url URL     Base URL（如 10.0.0.1:8080）"
        echo "    --port PORT        HTTP 端口（默认: 8080）"
        echo "    --interval SEC     git pull 间隔秒数（默认: 300）"
        echo "  uninstall-service  卸载 systemd 服务"
        echo "    --name NAME        服务名（默认: ${SERVICE_NAME}）"
        exit 1
        ;;
esac
