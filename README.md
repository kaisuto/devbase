# devbase

Personal dev container image based on Ubuntu 24.04.

## Included tools

| Category | Tools |
|----------|-------|
| Shell | zsh, Oh My Zsh, zsh-autosuggestions, zsh-syntax-highlighting |
| Editor utilities | fzf, ripgrep, fd, bat, eza, yq, jq |
| Multiplexer | zellij |
| Languages | Python (via uv), Go + Node.js LTS (via mise), Rust (via rustup) |
| AI | Claude Code |

## Usage

Reference this image in your project's `devcontainer.json`:

```json
{
    "image": "kaisuto/devbase:latest",
    "remoteUser": "vscode"
}
```

## Images

- Docker Hub: [`kaisuto/devbase`](https://hub.docker.com/r/kaisuto/devbase)
- GHCR: `ghcr.io/kaisuto/devbase`

## CI/CD

Pushes to `main` and version tags (`v*`) automatically build and publish multi-arch images (`linux/amd64`, `linux/arm64`) via GitHub Actions.
