#!/usr/bin/env bash
set -euo pipefail

# ── Load configuration ──────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.env"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi
set -a; source "$CONFIG_FILE"; set +a

MIRRORS_DIR="$DEVCONTAINERS_ROOT/cache/git-mirrors"
COMPOSE_FILE="$TEMPLATE_ROOT/.devcontainer/docker-compose.yml"
DOCKERFILE="$TEMPLATE_ROOT/.devcontainer/Dockerfile"

# ── Parse arguments ──────────────────────────────────────────────────────────
GITHUB_REPO=""
BRANCH_NAME=""
CONTAINER_NAME=""
PROJECT_TYPE=""
SHELL_INTO=true
BUILD_BASE=false

usage() {
    echo "Usage: devup <owner/repo> [options]"
    echo ""
    echo "Options:"
    echo "  -b, --branch NAME    Create/checkout this branch"
    echo "  -t, --type TYPE      Project type (nextjs, electron). Auto-detected if omitted."
    echo "  -n, --name NAME      Container name (default: auto-generated)"
    echo "  --no-shell            Don't attach shell after start"
    echo "  --build-base          Force rebuild the base Docker image"
    echo ""
    echo "Examples:"
    echo "  devup owner/my-app -b feat/new-feature"
    echo "  devup owner/my-app -b fix/bug -t nextjs"
    echo "  devup --build-base"
}

# Allow --build-base with no repo
if [ $# -ge 1 ] && [ "$1" = "--build-base" ]; then
    BUILD_BASE=true
    shift
fi

if [ "$BUILD_BASE" = true ] && [ $# -eq 0 ]; then
    echo "--- Building base image ---"
    docker build -t devcontainer-base:latest -f "$DOCKERFILE" "$(dirname "$DOCKERFILE")"
    echo "Base image rebuilt."
    exit 0
fi

if [ $# -lt 1 ]; then usage; exit 1; fi

GITHUB_REPO="$1"; shift
while [ $# -gt 0 ]; do
    case "$1" in
        -b|--branch)    BRANCH_NAME="$2"; shift 2 ;;
        -t|--type)      PROJECT_TYPE="$2"; shift 2 ;;
        -n|--name)      CONTAINER_NAME="$2"; shift 2 ;;
        --no-shell)     SHELL_INTO=false; shift ;;
        --build-base)   BUILD_BASE=true; shift ;;
        *)              echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# ── Auto-generate container name ─────────────────────────────────────────────
if [ -z "$CONTAINER_NAME" ]; then
    REPO_SHORT="${GITHUB_REPO##*/}"
    TIMESTAMP=$(date +%H%M%S)
    if [ -n "$BRANCH_NAME" ]; then
        BRANCH_SLUG="${BRANCH_NAME//\//-}"
        CONTAINER_NAME="${REPO_SHORT}-${BRANCH_SLUG}-${TIMESTAMP}"
    else
        CONTAINER_NAME="${REPO_SHORT}-${TIMESTAMP}"
    fi
fi

echo "=== devup: $GITHUB_REPO ==="
echo "  Container: $CONTAINER_NAME"
[ -n "$BRANCH_NAME" ] && echo "  Branch:    $BRANCH_NAME"
[ -n "$PROJECT_TYPE" ] && echo "  Type:      $PROJECT_TYPE"

# ── Step 1: Rebuild base image if requested ──────────────────────────────────
if [ "$BUILD_BASE" = true ]; then
    echo ""
    echo "--- Rebuilding base image ---"
    docker build -t devcontainer-base:latest -f "$DOCKERFILE" "$(dirname "$DOCKERFILE")"
fi

# ── Step 2: Ensure base image exists ─────────────────────────────────────────
if ! docker image inspect devcontainer-base:latest &>/dev/null; then
    echo ""
    echo "--- Building base image (first time) ---"
    docker build -t devcontainer-base:latest -f "$DOCKERFILE" "$(dirname "$DOCKERFILE")"
fi

# ── Step 3: Update git mirror ────────────────────────────────────────────────
MIRROR_NAME="${GITHUB_REPO//\//--}.git"
MIRROR_PATH="$MIRRORS_DIR/$MIRROR_NAME"

echo ""
echo "--- Git mirror ---"
mkdir -p "$MIRRORS_DIR"

if [ -d "$MIRROR_PATH" ]; then
    echo "  Fetching updates..."
    git -C "$MIRROR_PATH" fetch --all --prune --quiet
else
    echo "  Creating mirror (first time for this repo)..."
    git clone --mirror "https://github.com/$GITHUB_REPO" "$MIRROR_PATH"
fi

# ── Step 4: Start services ───────────────────────────────────────────────────
echo ""
echo "--- Starting container ---"

export GITHUB_REPO
export BRANCH_NAME
export PROJECT_TYPE
export DEVCONTAINERS_ROOT
export TEMPLATE_ROOT
export COMPOSE_PROJECT_NAME="$CONTAINER_NAME"

docker compose -f "$COMPOSE_FILE" up -d --wait

# ── Step 5: Attach shell ─────────────────────────────────────────────────────
if [ "$SHELL_INTO" = true ]; then
    echo ""
    echo "--- Attached (exit with Ctrl+D) ---"
    docker compose -p "$CONTAINER_NAME" -f "$COMPOSE_FILE" exec -u node -w /workspace app bash
fi
