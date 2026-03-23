# Agent Notes

Non-obvious details that can't be discovered by scanning the codebase.

## Two-directory architecture

- **`dev-container-template/`** (this repo) — The blueprint. Dockerfile, docker-compose, setup script, source copies of runtime scripts. Cloned from GitHub.
- **`devcontainers/`** (created by `setup.sh`) — Persistent host-side state. Config, caches, auth files, runtime scripts. Never in git.

The `devcontainers/.env` file stores machine-specific paths (`DEVCONTAINERS_ROOT`, `TEMPLATE_ROOT`, `GIT_BASH`). Scripts and docker-compose resolve all paths from these variables.

`setup.sh` bridges the two: it reads from the template repo and bootstraps the devcontainers directory, copying scripts and creating the directory structure.

## Claude Code config loading

Claude Code uses two separate config locations:
- `~/.claude/` — settings, credentials, skills, rules, commands (the directory)
- `~/.claude.json` — global state file in the home directory root (NOT inside `.claude/`). Contains `hasCompletedOnboarding`, `theme`, and `oauthAccount`. Without this file, Claude Code shows the onboarding wizard.

Both are copied (not mounted) from `devcontainers/config/` into the container by the entrypoint so Claude Code can write runtime state.

## Container naming

Docker Compose project name = `{repo-short}-{branch-slug}-{HHMMSS}`. Service containers are `{project}-app-1` and `{project}-db-1`.

## Entrypoint execution order

1. Copy git/gh/Claude/CodeRabbit config from read-only mounts to writable paths
2. Clone repo (using `--reference` from mirror if available)
3. Checkout/create branch
4. Auto-detect project type (`next.config.*` → nextjs, `electron` in package.json → electron)
5. Overlay includes: `global/` first, then type-specific on top
6. Create `.env` and set `DATABASE_URL`
7. Install deps (bun or npm based on lockfile)
8. Prisma generate + migrate (if `prisma/` exists)

## Git auth

Uses a fine-grained PAT via git credential-store. The credentials file is mounted read-only then copied to a writable path — the credential-store helper requires write access for lock files.

## Windows shell execution

The `.cmd` wrappers read `GIT_BASH` from `devcontainers/.env` to call Git Bash explicitly — PowerShell's `bash` resolves to WSL bash, which can't see Windows paths like `H:/devcontainers/...`.
