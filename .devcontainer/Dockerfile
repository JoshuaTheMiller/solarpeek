# ─────────────────────────────────────────────────────────────────────────────
# SolarPeak — Dev Container Image
#
# Ruby 3.2 (official image, Debian Bookworm) + Node 20 via NodeSource.
# Matches the runtime versions used in backend/Dockerfile.dev and
# frontend/Dockerfile.dev, but in a single image suited for VS Code /
# JetBrains devcontainer usage.
# ─────────────────────────────────────────────────────────────────────────────

FROM ruby:3.2-bookworm

# ── System packages ───────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl \
      git \
      sudo \
      gnupg \
      lsb-release \
      postgresql-client \
      redis-tools \
      build-essential \
      libpq-dev \
      tzdata \
    && rm -rf /var/lib/apt/lists/*

# ── Node 20 via NodeSource ────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g npm@latest \
    && rm -rf /var/lib/apt/lists/*

# ── Non-root user (matches VS Code devcontainer convention) ───────────────────
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd  --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# ── Global bundler config: write gems to the shared bundle_cache volume ───────
# (kept outside the workspace mount so gems survive container rebuilds)
ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_BIN=/usr/local/bundle/bin \
    GEM_HOME=/usr/local/bundle
ENV PATH="${BUNDLE_BIN}:${PATH}"

USER ${USERNAME}
