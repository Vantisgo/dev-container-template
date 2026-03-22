# Dev Container Template

Spin up pre-configured dev containers with PostgreSQL, Claude Code, and GitHub auth in seconds. Designed for high-throughput workflows (10-20 containers/day) with caching at every layer.

## Features

- **One command** to clone a repo, install deps, set up the database, and drop into a shell
- **PostgreSQL 17** available in every container, `DATABASE_URL` auto-configured in `.env`
- **Claude Code** pre-installed with full config (settings, skills, rules, agents, credentials)
- **GitHub private repos** supported via fine-grained PAT (no interactive login)
- **Fast startup** through layered caching: Docker image, git mirrors, bun/npm package cache
- **Project-type includes** — overlay files (CLAUDE.md, skills, rules) into workspaces without committing them to the repo
- **Auto-detection** of project type (Next.js, Electron) for type-specific config

## Quick Start

```bash
# One-time setup: build the base image
bash H:/devcontainers/scripts/devup.sh --build-base

# Spin up a container
bash H:/devcontainers/scripts/devup.sh owner/repo -b feat/my-branch

# Tear down
bash H:/devcontainers/scripts/devdown.sh owner-repo-feat-my-branch-143022
```

## Commands

### `devup`

```
devup <owner/repo> [options]

Options:
  -b, --branch NAME    Create or checkout a branch
  -t, --type TYPE      Project type: nextjs, electron (auto-detected if omitted)
  -n, --name NAME      Custom container name (default: auto-generated)
  --no-shell            Start without attaching a shell
  --build-base          Rebuild the base Docker image
```

### `devdown`

```
devdown <container-name>    Stop and remove a specific container
devdown --all               Stop and remove all dev containers
devdown --list              List running dev containers
```

## Attaching to a Running Container

```bash
docker exec -it -u node <project>-app-1 bash -c "cd /workspace && bash"
```

## Directory Layout

```
H:/dev-container-template/         # This repo (Docker template)
  .devcontainer/
    Dockerfile                     # Base image: Node 22, Bun, gh CLI, Claude Code, psql
    docker-compose.yml             # App + PostgreSQL, all volume mounts
    devcontainer.json              # VS Code attach support

H:/devcontainers/                  # Persistent host-side state (shared across all repos)
  config/
    gitconfig                      # Git user + credential helper
    git-credentials                # Fine-grained PAT
    gh/hosts.yml                   # GitHub CLI auth
    claude/                        # Claude Code config (settings, skills, rules, etc.)
    claude.json                    # Claude Code global state (onboarding, theme, auth)
  cache/
    git-mirrors/                   # Bare repo mirrors for fast --reference clones
    bun-cache/                     # Shared bun download cache
    npm-cache/                     # Shared npm download cache
  includes/
    global/                        # Files overlaid into every workspace
    nextjs/                        # Files overlaid for Next.js projects
    electron/                      # Files overlaid for Electron projects
  scripts/
    devup.sh                       # Main orchestrator
    devdown.sh                     # Cleanup
    entrypoint.sh                  # Runs inside every container at startup
```

## Initial Setup

1. **Fill in git credentials** in `H:/devcontainers/config/`:
   - `gitconfig` — your name and email
   - `git-credentials` — `https://USERNAME:FINE_GRAINED_PAT@github.com`
   - `gh/hosts.yml` — same PAT and username

2. **Set up Claude Code auth** — two files needed:
   - `config/claude/.credentials.json` — OAuth tokens. Copy from `~/.claude/.credentials.json` on a machine where you've run `claude` and logged in.
   - `config/claude.json` — onboarding state + OAuth account info. Copy from `~/.claude.json` (home directory root, NOT inside `.claude/`). This file prevents the first-run setup wizard.
   - Optionally copy settings, skills, rules, commands, and agents into `config/claude/`.

3. **Set up CodeRabbit auth**:
   - `config/coderabbit/auth.json` — Copy from `~/.coderabbit/auth.json` on a machine where you've run `coderabbit auth login`.

4. **Build the base image**: `bash H:/devcontainers/scripts/devup.sh --build-base`

5. **Rebuild periodically** to pick up updates (Node.js, Claude Code, Bun): run `--build-base` again.

## Caching

| Layer | Location | Shared across repos |
|---|---|---|
| Docker base image | Local Docker daemon | Yes |
| Git objects | `cache/git-mirrors/` (bare mirrors) | Per-repo |
| Bun packages | `cache/bun-cache/` | Yes |
| npm packages | `cache/npm-cache/` | Yes |
| Claude Code config | `config/claude/` + `config/claude.json` | Yes |
| Git/GitHub auth | `config/gitconfig` + `config/git-credentials` | Yes |
