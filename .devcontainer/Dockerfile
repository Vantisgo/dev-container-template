FROM mcr.microsoft.com/devcontainers/javascript-node:22

# ── System packages: GitHub CLI + PostgreSQL client ──────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh postgresql-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── Bun (system-wide) ───────────────────────────────────────────────────────
RUN curl -fsSL https://bun.sh/install | BUN_INSTALL=/usr/local bash

# ── Claude Code ──────────────────────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code

# ── Git defaults ─────────────────────────────────────────────────────────────
RUN git config --system init.defaultBranch main \
    && git config --system push.autoSetupRemote true

# ── Pre-create cache/config directories with correct ownership ───────────────
RUN mkdir -p /home/node/.bun/install/cache \
    && mkdir -p /home/node/.npm \
    && mkdir -p /home/node/.claude/skills \
    && mkdir -p /home/node/.agents/skills \
    && mkdir -p /home/node/.config/gh \
    && mkdir -p /cache/git-mirrors \
    && mkdir -p /workspace \
    && chown -R node:node /home/node/.bun /home/node/.npm \
       /home/node/.claude /home/node/.agents /home/node/.config/gh /cache /workspace
