FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG RUBY_VERSION=3.2.0
ARG NODE_MAJOR=20
ARG USERNAME=vscode

ENV DEBIAN_FRONTEND=noninteractive
ENV RBENV_ROOT=/usr/local/rbenv
ENV PATH=/usr/local/rbenv/shims:/usr/local/rbenv/bin:${PATH}

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    bison \
    build-essential \
    ca-certificates \
    curl \
    git \
    libdb-dev \
    libffi-dev \
    libgdbm-dev \
    libgmp-dev \
    libncurses5-dev \
    libreadline-dev \
    libssl-dev \
    libyaml-dev \
    patch \
    rustc \
    uuid-dev \
    xz-utils \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/rbenv/rbenv.git ${RBENV_ROOT} \
    && mkdir -p ${RBENV_ROOT}/plugins \
    && git clone https://github.com/rbenv/ruby-build.git ${RBENV_ROOT}/plugins/ruby-build \
    && ${RBENV_ROOT}/bin/rbenv install -s ${RUBY_VERSION} \
    && ${RBENV_ROOT}/bin/rbenv global ${RUBY_VERSION} \
    && gem install bundler \
    && rbenv rehash

RUN chown -R ${USERNAME}:${USERNAME} ${RBENV_ROOT}

USER ${USERNAME}
