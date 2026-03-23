#!/usr/bin/env bash
set -euo pipefail

# ── Dev Container Setup ─────────────────────────────────────────────────────
# Run once on a new machine to bootstrap the devcontainers/ directory.
# Usage: bash setup.sh [target-directory]
#   e.g. bash setup.sh H:/devcontainers

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Dev Container Setup ==="
echo ""

# ── Pick target directory ────────────────────────────────────────────────────
if [ -n "${1:-}" ]; then
    TARGET="$1"
else
    read -rp "Where should the devcontainers directory live? (e.g. H:/devcontainers): " TARGET
fi

if [ -z "$TARGET" ]; then
    echo "Error: No target directory specified."
    exit 1
fi

# ── Detect Git Bash path ────────────────────────────────────────────────────
GIT_BASH_PATH=""
for candidate in \
    "C:/Program Files/Git/usr/bin/bash.exe" \
    "/c/Program Files/Git/usr/bin/bash.exe" \
    "/usr/bin/bash"; do
    if [ -f "$candidate" ]; then
        GIT_BASH_PATH="$candidate"
        break
    fi
done
if [ -z "$GIT_BASH_PATH" ]; then
    read -rp "Path to Git Bash (bash.exe): " GIT_BASH_PATH
fi

echo ""
echo "  Target:    $TARGET"
echo "  Template:  $TEMPLATE_DIR"
echo "  Git Bash:  $GIT_BASH_PATH"
echo ""

# ── Create directory structure ───────────────────────────────────────────────
echo "--- Creating directories ---"
mkdir -p "$TARGET/cache/git-mirrors"
mkdir -p "$TARGET/cache/bun-cache"
mkdir -p "$TARGET/cache/npm-cache"
mkdir -p "$TARGET/config/claude/skills"
mkdir -p "$TARGET/config/claude/rules"
mkdir -p "$TARGET/config/claude/commands"
mkdir -p "$TARGET/config/claude/agents"
mkdir -p "$TARGET/config/coderabbit"
mkdir -p "$TARGET/config/gh"
mkdir -p "$TARGET/includes/global/.claude"
mkdir -p "$TARGET/includes/nextjs/.claude"
mkdir -p "$TARGET/includes/electron/.claude"
mkdir -p "$TARGET/scripts"

# ── Write .env ───────────────────────────────────────────────────────────────
ENV_FILE="$TARGET/.env"
if [ -f "$ENV_FILE" ]; then
    echo "  .env already exists, skipping."
else
    cat > "$ENV_FILE" <<ENVEOF
# Dev Container Configuration
# Paths use forward slashes (works in Git Bash and Docker Desktop)
DEVCONTAINERS_ROOT=$TARGET
TEMPLATE_ROOT=$TEMPLATE_DIR
GIT_BASH="$GIT_BASH_PATH"
ENVEOF
    echo "  Created .env"
fi

# ── Copy scripts ─────────────────────────────────────────────────────────────
echo ""
echo "--- Copying scripts ---"
for script in devup.sh devup.cmd devdown.sh devdown.cmd entrypoint.sh; do
    SRC="$TEMPLATE_DIR/scripts/$script"
    if [ -f "$SRC" ]; then
        cp -f "$SRC" "$TARGET/scripts/$script"
        echo "  $script"
    fi
done

# ── Create placeholder config files ─────────────────────────────────────────
echo ""
echo "--- Config files ---"

# Git
if [ ! -f "$TARGET/config/gitconfig" ]; then
    read -rp "  Git name (e.g. Xanacas): " GIT_NAME
    read -rp "  Git email: " GIT_EMAIL
    cat > "$TARGET/config/gitconfig" <<GITEOF
[user]
    name = $GIT_NAME
    email = $GIT_EMAIL

[credential]
    helper = store --file=/home/node/.git-credentials

[init]
    defaultBranch = main

[push]
    autoSetupRemote = true
GITEOF
    echo "  Created gitconfig"
else
    echo "  gitconfig already exists, skipping."
fi

if [ ! -f "$TARGET/config/git-credentials" ]; then
    read -rp "  GitHub username: " GH_USER
    read -rsp "  GitHub fine-grained PAT: " GH_PAT
    echo ""
    echo "https://$GH_USER:$GH_PAT@github.com" > "$TARGET/config/git-credentials"
    echo "  Created git-credentials"

    # Also write gh CLI config
    cat > "$TARGET/config/gh/hosts.yml" <<GHEOF
github.com:
    oauth_token: $GH_PAT
    user: $GH_USER
    git_protocol: https
GHEOF
    echo "  Created gh/hosts.yml"
else
    echo "  git-credentials already exists, skipping."
fi

# Claude Code
if [ ! -f "$TARGET/config/claude/.credentials.json" ]; then
    echo ""
    echo "  Claude Code credentials not found."
    echo "  To set up, copy these files from a machine where Claude Code is authenticated:"
    echo "    ~/.claude/.credentials.json  ->  $TARGET/config/claude/.credentials.json"
    echo "    ~/.claude.json               ->  $TARGET/config/claude.json"
    echo "  Or run 'claude' and log in, then re-run this setup."
else
    echo "  Claude Code credentials found."
fi

# Claude Code global state
if [ ! -f "$TARGET/config/claude.json" ]; then
    echo "  Claude Code global state (.claude.json) not found."
    echo "  Copy from ~/.claude.json on an authenticated machine."
else
    echo "  Claude Code global state found."
fi

# CodeRabbit
if [ ! -f "$TARGET/config/coderabbit/auth.json" ]; then
    echo ""
    echo "  CodeRabbit auth not found."
    echo "  To set up, copy from a machine where CodeRabbit CLI is authenticated:"
    echo "    ~/.coderabbit/auth.json  ->  $TARGET/config/coderabbit/auth.json"
    echo "  Or run 'coderabbit auth login' and then copy the file."
else
    echo "  CodeRabbit auth found."
fi

# ── Add scripts to PATH ─────────────────────────────────────────────────────
echo ""
echo "--- PATH ---"
SCRIPTS_DIR="$TARGET/scripts"
case "$PATH" in
    *"$SCRIPTS_DIR"*) echo "  Scripts already on PATH." ;;
    *)
        echo "  Add this to your PATH to use devup/devdown from anywhere:"
        echo "    $SCRIPTS_DIR"
        read -rp "  Add to Windows user PATH now? (y/N): " ADD_PATH
        if [[ "$ADD_PATH" =~ ^[Yy]$ ]]; then
            powershell.exe -Command "[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'User') + ';${SCRIPTS_DIR}', 'User')" 2>/dev/null || true
            echo "  Added. Restart your terminal for it to take effect."
        fi
        ;;
esac

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Fill in any missing auth files listed above"
echo "  2. Build the base image:  devup --build-base"
echo "  3. Spin up a container:   devup owner/repo -b branch"
