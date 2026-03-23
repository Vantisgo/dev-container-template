#!/usr/bin/env bash
set -euo pipefail

HOST_CONFIG="/home/node/.host-config"

# ── Copy host config to writable locations ───────────────────────────────────
# Everything under .host-config/ is mounted read-only. We copy to writable
# paths so tools (git credential-store, gh, Claude Code) can write runtime state.

# Git
if [ -f "$HOST_CONFIG/gitconfig" ]; then
    cp -f "$HOST_CONFIG/gitconfig" /home/node/.gitconfig
fi
if [ -f "$HOST_CONFIG/git-credentials" ]; then
    cp -f "$HOST_CONFIG/git-credentials" /home/node/.git-credentials
    # Update credential helper to point to the writable copy
    git config --global credential.helper "store --file=/home/node/.git-credentials"
fi

# GitHub CLI
if [ -d "$HOST_CONFIG/gh" ]; then
    mkdir -p /home/node/.config/gh
    cp -rf "$HOST_CONFIG/gh/." /home/node/.config/gh/
fi
if command -v gh &>/dev/null; then
    gh auth setup-git 2>/dev/null || true
fi

# Claude Code
CLAUDE_HOME="/home/node/.claude"
if [ -d "$HOST_CONFIG/claude" ]; then
    mkdir -p "$CLAUDE_HOME"
    cp -rf "$HOST_CONFIG/claude/." "$CLAUDE_HOME/"
fi
# Claude Code global state (~/.claude.json — onboarding, theme, oauth account)
if [ -f "$HOST_CONFIG/claude.json" ]; then
    cp -f "$HOST_CONFIG/claude.json" /home/node/.claude.json
fi

# CodeRabbit
if [ -d "$HOST_CONFIG/coderabbit" ]; then
    mkdir -p /home/node/.coderabbit
    cp -rf "$HOST_CONFIG/coderabbit/." /home/node/.coderabbit/
fi

# ── Clone repository if GITHUB_REPO is set ───────────────────────────────────
if [ -n "${GITHUB_REPO:-}" ]; then
    REPO_SLUG="${GITHUB_REPO#https://github.com/}"
    REPO_SLUG="${REPO_SLUG%.git}"
    MIRROR_NAME="${REPO_SLUG//\//--}.git"
    MIRROR_PATH="/cache/git-mirrors/$MIRROR_NAME"

    if [ ! -d /workspace/.git ]; then
        CLONE_ARGS=()
        if [ -d "$MIRROR_PATH" ]; then
            CLONE_ARGS+=("--reference" "$MIRROR_PATH")
        fi
        git clone "${CLONE_ARGS[@]}" "https://github.com/$REPO_SLUG" /workspace
    else
        cd /workspace && git fetch --all --quiet
    fi

    cd /workspace

    # ── Create or checkout branch ──
    if [ -n "${BRANCH_NAME:-}" ]; then
        if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
            git checkout "$BRANCH_NAME"
        elif git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME" 2>/dev/null; then
            git checkout -b "$BRANCH_NAME" "origin/$BRANCH_NAME"
        else
            git checkout -b "$BRANCH_NAME"
        fi
    fi

    # ── Auto-detect project type if not set ──
    if [ -z "${PROJECT_TYPE:-}" ]; then
        if ls next.config.* &>/dev/null; then
            PROJECT_TYPE="nextjs"
        elif [ -f package.json ] && grep -q '"electron"' package.json 2>/dev/null; then
            PROJECT_TYPE="electron"
        fi
    fi

    # ── Apply includes: global first, then type-specific on top ──
    if [ -d /includes/global ]; then
        cp -rf /includes/global/. /workspace/ 2>/dev/null || true
    fi
    if [ -n "${PROJECT_TYPE:-}" ] && [ -d "/includes/$PROJECT_TYPE" ]; then
        cp -rf "/includes/$PROJECT_TYPE/." /workspace/ 2>/dev/null || true
    fi

    # ── Environment setup ──
    if [ -f .env.example ] && [ ! -f .env ]; then
        cp .env.example .env
    fi
    # Create .env if it still doesn't exist (repo has no .env.example)
    if [ ! -f .env ]; then
        touch .env
    fi
    if grep -q '^DATABASE_URL=' .env; then
        sed -i 's|^DATABASE_URL=.*|DATABASE_URL=postgresql://postgres:postgres@db:5432/devdb|' .env
    else
        echo 'DATABASE_URL=postgresql://postgres:postgres@db:5432/devdb' >> .env
    fi

    # ── Install dependencies ──
    if [ -f package.json ]; then
        if [ -f bun.lock ] || [ -f bun.lockb ]; then
            bun install
        elif [ -f package-lock.json ]; then
            npm ci
        else
            bun install
        fi
    fi

    # ── Prisma ──
    if [ -d prisma ]; then
        if command -v bun &>/dev/null; then
            bun --bun run prisma generate
            if [ -d prisma/migrations ]; then
                bun --bun run prisma migrate deploy
            else
                bun --bun run prisma db push
            fi
        else
            npx prisma generate
            if [ -d prisma/migrations ]; then
                npx prisma migrate deploy
            else
                npx prisma db push
            fi
        fi
    fi
fi

echo "Dev container ready.${PROJECT_TYPE:+ (type: $PROJECT_TYPE)}"

# Hand off to CMD (default: sleep infinity)
exec "$@"
