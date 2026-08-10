# obsidian-quartz-serve

English | [简体中文](README.zh-CN.md)

Deploy any Obsidian vault as a [Quartz v4](https://github.com/jackyzha0/quartz) website with a single script.

**Drop `serve.sh` into the root of an Obsidian vault** to launch a static website with search, backlinks, and graph views. A background `git pull` loop keeps the published notes up to date automatically.

## Features

- 🚀 Initializes Quartz automatically on first run (`git clone` + `npm install`)
- 🔄 Pulls the latest notes with `git pull` every five minutes
- 🌐 Serves a website with search, backlinks, and knowledge graphs
- 🛠️ Includes systemd service management for one-command installation, removal, and automatic restarts

## Quick start

```bash
# Copy serve.sh to the root of your Obsidian vault
cp serve.sh /path/to/your-vault/
cd /path/to/your-vault/

# Run it directly (listens on 0.0.0.0:8080 by default)
chmod +x serve.sh
./serve.sh

# Set the public address used for absolute URLs in page metadata.
# This does not change the listening address.
BASE_URL="10.0.0.1:8080" ./serve.sh
```

## Manage the server with systemd

Recommended for server deployments. The service name is generated from the vault directory as `quartz-<directory-name>`. Use `--name` to override it.

```bash
# Install and start the service
sudo ./serve.sh install-service

# Set options during installation
sudo ./serve.sh install-service --base-url 10.0.0.1:8080 --port 8080

# Use a custom service name
sudo ./serve.sh install-service --name my-notes --base-url 10.0.0.1:3000 --port 3000

# Follow the logs
sudo journalctl -u <service-name> -f  # Defaults to quartz-<directory-name>

# Uninstall the service
sudo ./serve.sh uninstall-service
```

## Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `SERVE_PORT` | `8080` | HTTP listening port |
| `BASE_URL` | `localhost:$SERVE_PORT` | Public address used for absolute URLs in page metadata; set this to the actual IP address or domain for public deployments |
| `GIT_PULL_INTERVAL` | `300` | Interval between `git pull` attempts, in seconds |

## Requirements

- Node.js 20 or later (installation through nvm is recommended)
- Git
- systemd (only when using the service management commands)

## How it works

1. On first run, the script clones Quartz v4 into `.quartz/` and installs its dependencies.
2. It maintains `.gitignore` entries for `.quartz/`, `.service-name`, and `node_modules/`.
3. It generates `quartz.config.ts` from the environment settings, with Simplified Chinese typography and a dark theme.
4. It starts a background `git pull` loop to keep the vault content current.
5. If the vault has no root-level `index.md`, it creates a default home page.
6. It starts the Quartz development server with file watching and automatic rebuilds.

```text
your-vault/
├── serve.sh          # This script
├── .quartz/          # Generated Quartz runtime
├── .service-name     # Generated systemd service-name record
├── index.md
├── notes/
│   ├── topic-a.md
│   └── topic-b.md
└── assets/
    └── images/
```

## About `.service-name`

When you run `install-service`, the script writes the installed systemd service name to `.service-name` in the vault root.

- `uninstall-service` reads this file to find and remove the service without requiring `--name`.
- If you delete the file manually, pass the service name explicitly with `--name` when uninstalling.

## License

MIT
