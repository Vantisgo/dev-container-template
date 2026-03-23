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

export DEVCONTAINERS_ROOT
export TEMPLATE_ROOT
COMPOSE_FILE="$TEMPLATE_ROOT/.devcontainer/docker-compose.yml"

usage() {
    echo "Usage:"
    echo "  devdown <container-name>   Stop and remove a specific container"
    echo "  devdown --all              Stop and remove all dev containers"
    echo "  devdown --list             List running dev containers"
}

if [ $# -lt 1 ]; then usage; exit 1; fi

case "$1" in
    --list)
        docker compose ls
        ;;
    --all)
        echo "Stopping all dev containers..."
        for project in $(docker compose ls -q 2>/dev/null); do
            COMPOSE_PROJECT_NAME="$project" docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true
        done
        echo "Done."
        ;;
    *)
        echo "Stopping: $1"
        COMPOSE_PROJECT_NAME="$1" docker compose -f "$COMPOSE_FILE" down -v
        echo "Done."
        ;;
esac
