FROM ubuntu:24.04

SHELL ["/bin/bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
ARG TARGETARCH=amd64

# ── System packages ───────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl wget unzip \
        jq \
        zsh vim \
        build-essential ca-certificates gnupg \
        openssh-client \
        ripgrep fd-find bat \
        bsdextrautils \
        sudo \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat \
    && rm -rf /var/lib/apt/lists/*

# ── yq ────────────────────────────────────────────────────────────────────────
RUN --mount=type=secret,id=GITHUB_TOKEN \
    set -euxo pipefail; \
    TOKEN=$(cat /run/secrets/GITHUB_TOKEN 2>/dev/null || echo ""); \
    case "${TARGETARCH}" in \
        amd64) YQ_ARCH="amd64" ;; \
        arm64) YQ_ARCH="arm64" ;; \
    esac; \
    if [ -n "${TOKEN}" ]; then \
        YQ_VER=$(curl -fsSL -H "Authorization: token ${TOKEN}" \
                 https://api.github.com/repos/mikefarah/yq/releases/latest \
                 | jq -er '.tag_name'); \
    else \
        YQ_VER=$(curl -fsSL https://api.github.com/repos/mikefarah/yq/releases/latest \
                 | jq -er '.tag_name'); \
    fi; \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VER}/yq_linux_${YQ_ARCH}" \
         -o /usr/local/bin/yq; \
    chmod +x /usr/local/bin/yq

# ── eza ───────────────────────────────────────────────────────────────────────
RUN --mount=type=secret,id=GITHUB_TOKEN \
    set -euxo pipefail; \
    TOKEN=$(cat /run/secrets/GITHUB_TOKEN 2>/dev/null || echo ""); \
    case "${TARGETARCH}" in \
        amd64) EZA_ARCH="x86_64-unknown-linux-gnu" ;; \
        arm64) EZA_ARCH="aarch64-unknown-linux-gnu" ;; \
    esac; \
    if [ -n "${TOKEN}" ]; then \
        EZA_VER=$(curl -fsSL -H "Authorization: token ${TOKEN}" \
                  https://api.github.com/repos/eza-community/eza/releases/latest \
                  | jq -er '.tag_name'); \
    else \
        EZA_VER=$(curl -fsSL https://api.github.com/repos/eza-community/eza/releases/latest \
                  | jq -er '.tag_name'); \
    fi; \
    curl -fsSL "https://github.com/eza-community/eza/releases/download/${EZA_VER}/eza_${EZA_ARCH}.tar.gz" \
    | tar xz -C /usr/local/bin

# ── zellij ────────────────────────────────────────────────────────────────────
RUN --mount=type=secret,id=GITHUB_TOKEN \
    set -euxo pipefail; \
    TOKEN=$(cat /run/secrets/GITHUB_TOKEN 2>/dev/null || echo ""); \
    case "${TARGETARCH}" in \
        amd64) ZELLIJ_ARCH="x86_64-unknown-linux-musl" ;; \
        arm64) ZELLIJ_ARCH="aarch64-unknown-linux-musl" ;; \
    esac; \
    if [ -n "${TOKEN}" ]; then \
        ZELLIJ_VER=$(curl -fsSL -H "Authorization: token ${TOKEN}" \
                     https://api.github.com/repos/zellij-org/zellij/releases/latest \
                     | jq -er '.tag_name'); \
    else \
        ZELLIJ_VER=$(curl -fsSL https://api.github.com/repos/zellij-org/zellij/releases/latest \
                     | jq -er '.tag_name'); \
    fi; \
    curl -fsSL "https://github.com/zellij-org/zellij/releases/download/${ZELLIJ_VER}/zellij-${ZELLIJ_ARCH}.tar.gz" \
    | tar xz -C /usr/local/bin

# ── Non-root user ─────────────────────────────────────────────────────────────
RUN userdel -r ubuntu 2>/dev/null || true; \
    groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /usr/bin/zsh ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# ── fzf ───────────────────────────────────────────────────────────────────────
RUN git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf \
    && ~/.fzf/install --bin

# ── Python via uv ─────────────────────────────────────────────────────────────
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"
RUN uv python install 3.14 \
    && PYTHON_BIN=$(uv python find 3.14) \
    && sudo ln -sf "${PYTHON_BIN}" /usr/local/bin/python3 \
    && sudo ln -sf "${PYTHON_BIN}" /usr/local/bin/python

# ── mise (Go + Node.js) ───────────────────────────────────────────────────────
RUN curl https://mise.run | sh
ENV PATH="/home/${USERNAME}/.local/share/mise/shims:${PATH}"
RUN mise use --global go@latest node@lts
ENV GOPATH="/home/${USERNAME}/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# ── Claude Code ───────────────────────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code

# ── Rust via rustup ───────────────────────────────────────────────────────────
ENV RUSTUP_HOME="/home/${USERNAME}/.rustup"
ENV CARGO_HOME="/home/${USERNAME}/.cargo"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --no-modify-path
ENV PATH="/home/${USERNAME}/.cargo/bin:${PATH}"

# ── Oh My Zsh + plugins ───────────────────────────────────────────────────────
ENV ZSH="/home/${USERNAME}/.oh-my-zsh"
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended

RUN git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
        "${ZSH}/custom/plugins/zsh-autosuggestions" \
    && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
        "${ZSH}/custom/plugins/zsh-syntax-highlighting"

COPY --chown=${USERNAME}:${USERNAME} .devcontainer/zshrc /home/${USERNAME}/.zshrc

CMD ["zsh"]
