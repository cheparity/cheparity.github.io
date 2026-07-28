#!/usr/bin/env bash
# =============================================================================
# bootstrap-dev-env.sh — One-click dev environment setup for a fresh Ubuntu machine
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/cheparity/cheparity.github.io/master/scripts/bootstrap-dev-env.sh | bash
#
# Phase 1 (no auth):  Base tools + dev runtimes
# Phase 2 (auth):     GitHub auth + chezmoi dotfiles
# Phase 3 (agent):    omp agent
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

section() { echo -e "\n${CYAN}==>${NC} ${CYAN}$1${NC}"; }
ok()      { echo -e "  ${GREEN}✓${NC} $1"; }
skip()    { echo -e "  ${YELLOW}○${NC} $1 (already installed, skipping)"; }
warn()    { echo -e "  ${YELLOW}⚠${NC} $1"; }

have()    { command -v "$1" >/dev/null 2>&1; }

# Use sudo only when not root
SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

NO_DOTFILES=false
[[ "${1:-}" == "--no-dotfiles" ]] && NO_DOTFILES=true

# Architecture detection (for jq / gh binary downloads)
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH=amd64 ;;
    aarch64) ARCH=arm64 ;;
    *)       warn "Unrecognized arch $ARCH, defaulting to amd64"; ARCH=amd64 ;;
esac

# OS detection (apt deps only installed on Ubuntu)
IS_UBUNTU=false
if [ -f /etc/os-release ] && grep -qi '^ID=ubuntu' /etc/os-release; then
    IS_UBUNTU=true
fi

# =============================================================================
# Phase 1: Base tools + dev runtimes (no auth)
# =============================================================================

section "Phase 1: Base tools + dev runtimes"

# ---- apt dependencies ----
echo ""
echo -e "  ${CYAN}▸${NC} System dependencies (apt)"
if [ "$IS_UBUNTU" = true ]; then
    $SUDO apt-get update -qq

    APT_PKGS=(build-essential curl git tmux unzip p7zip-full)
    TO_INSTALL=()
    for pkg in "${APT_PKGS[@]}"; do
        dpkg -s "$pkg" &>/dev/null && skip "$pkg" || TO_INSTALL+=("$pkg")
    done
    if [ ${#TO_INSTALL[@]} -gt 0 ]; then
        $SUDO apt-get install -y -qq "${TO_INSTALL[@]}"
        ok "Installed: ${TO_INSTALL[*]}"
    fi
else
    warn "Not Ubuntu, skipping apt dependencies"
fi

# ---- jq ----
echo ""
echo -e "  ${CYAN}▸${NC} jq (JSON processor)"
if have jq; then
    skip "jq"
else
    curl -fsSL "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-${ARCH}" \
        -o /tmp/jq
    chmod +x /tmp/jq
    $SUDO mv /tmp/jq /usr/local/bin/jq
    ok "jq installed"
fi

# ---- Rust (rustup) ----
echo ""
echo -e "  ${CYAN}▸${NC} Rust (rustup → cargo)"
if have cargo; then
    skip "rust"
else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    . "$HOME/.cargo/env"
    ok "rust installed"
fi

# ---- uv ----
echo ""
echo -e "  ${CYAN}▸${NC} uv (Python package manager)"
if have uv; then
    skip "uv"
else
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    ok "uv installed"
fi

# ---- Bun ----
echo ""
echo -e "  ${CYAN}▸${NC} Bun (JavaScript runtime)"
if have bun; then
    skip "bun"
else
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
    ok "bun installed"
fi

# ---- chezmoi ----
echo ""
echo -e "  ${CYAN}▸${NC} chezmoi (dotfiles manager)"
if have chezmoi; then
    skip "chezmoi"
else
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
    ok "chezmoi installed"
fi

# ---- Neovim ----
echo ""
echo -e "  ${CYAN}▸${NC} Neovim (>= 0.11.2, LuaJIT)"
if have nvim; then
    skip "nvim"
else
    NVIM_ARCH=$([ "$ARCH" = "amd64" ] && echo x86_64 || echo arm64)
    NVIM_VERSION=$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest | jq -r '.tag_name')
    curl -fsSL "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-${NVIM_ARCH}.tar.gz" \
        | $SUDO tar xz -C /opt
    $SUDO ln -sf /opt/nvim-linux-${NVIM_ARCH}/bin/nvim /usr/local/bin/nvim
    ok "nvim installed"
fi

# ---- Nerd Fonts ----
echo ""
echo -e "  ${CYAN}▸${NC} Nerd Fonts (JetBrainsMono Nerd Font + Iosevka Nerd Font, optional)"
for FONT in JetBrainsMono Iosevka; do
    FONT_DIR="$HOME/.local/share/fonts/$FONT"
    if [ -d "$FONT_DIR" ]; then
        skip "$FONT Nerd Font"
    else
        mkdir -p "$FONT_DIR"
        curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${FONT}.tar.xz" \
            | tar xJ -C "$FONT_DIR"
        ok "$FONT Nerd Font installed"
    fi
done
fc-cache -f "$HOME/.local/share/fonts" &>/dev/null || true

# ---- lazygit ----
echo ""
echo -e "  ${CYAN}▸${NC} lazygit (optional)"
if have lazygit; then
    skip "lazygit"
else
    LG_ARCH=$([ "$ARCH" = "amd64" ] && echo x86_64 || echo arm64)
    LG_VERSION=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | jq -r '.tag_name' | sed 's/^v//')
    curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LG_VERSION}/lazygit_${LG_VERSION}_Linux_${LG_ARCH}.tar.gz" \
        | tar xz -C /tmp lazygit
    $SUDO mv /tmp/lazygit /usr/local/bin/lazygit
    ok "lazygit installed"
fi

# ---- tree-sitter-cli ----
echo ""
echo -e "  ${CYAN}▸${NC} tree-sitter-cli (nvim-treesitter)"
if have tree-sitter; then
    skip "tree-sitter"
else
    TS_ARCH=$([ "$ARCH" = "amd64" ] && echo x64 || echo arm64)
    TS_VERSION=$(curl -fsSL https://api.github.com/repos/tree-sitter/tree-sitter/releases/latest | jq -r '.tag_name')
    curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/download/${TS_VERSION}/tree-sitter-cli-linux-${TS_ARCH}.zip" \
        -o /tmp/tree-sitter-cli.zip
    unzip -o /tmp/tree-sitter-cli.zip -d /tmp/tree-sitter-cli
    $SUDO mv /tmp/tree-sitter-cli/tree-sitter /usr/local/bin/tree-sitter
    rm -rf /tmp/tree-sitter-cli /tmp/tree-sitter-cli.zip
    ok "tree-sitter-cli installed"
fi

# ---- fzf ----
echo ""
echo -e "  ${CYAN}▸${NC} fzf (fzf-lua, optional)"
if have fzf; then
    skip "fzf"
else
    FZF_VERSION=$(curl -fsSL https://api.github.com/repos/junegunn/fzf/releases/latest | jq -r '.tag_name' | sed 's/^v//')
    curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_${ARCH}.tar.gz" \
        | tar xz -C /tmp
    $SUDO mv /tmp/fzf /usr/local/bin/fzf
    ok "fzf installed"
fi

# ---- ripgrep ----
echo ""
echo -e "  ${CYAN}▸${NC} ripgrep (fzf-lua live grep)"
if have rg; then
    skip "ripgrep"
else
    RG_ARCH=$([ "$ARCH" = "amd64" ] && echo x86_64 || echo aarch64)
    RG_VERSION=$(curl -fsSL https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | jq -r '.tag_name')
    curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/ripgrep-${RG_VERSION}-${RG_ARCH}-unknown-linux-musl.tar.gz" \
        | tar xz -C /tmp
    $SUDO mv "/tmp/ripgrep-${RG_VERSION}-${RG_ARCH}-unknown-linux-musl/rg" /usr/local/bin/rg
    rm -rf "/tmp/ripgrep-${RG_VERSION}-${RG_ARCH}-unknown-linux-musl"
    ok "ripgrep installed"
fi

# ---- fd ----
echo ""
echo -e "  ${CYAN}▸${NC} fd (fzf-lua find files)"
if have fd || have fdfind; then
    skip "fd"
else
    FD_ARCH=$([ "$ARCH" = "amd64" ] && echo x86_64 || echo aarch64)
    FD_VERSION=$(curl -fsSL https://api.github.com/repos/sharkdp/fd/releases/latest | jq -r '.tag_name')
    curl -fsSL "https://github.com/sharkdp/fd/releases/download/${FD_VERSION}/fd-${FD_VERSION}-${FD_ARCH}-unknown-linux-gnu.tar.gz" \
        | tar xz -C /tmp
    $SUDO mv "/tmp/fd-${FD_VERSION}-${FD_ARCH}-unknown-linux-gnu/fd" /usr/local/bin/fd
    rm -rf "/tmp/fd-${FD_VERSION}-${FD_ARCH}-unknown-linux-gnu"
    ok "fd installed"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Phase 1 done${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# =============================================================================
# Phase 2: GitHub auth + dotfiles
# =============================================================================

if [ "$NO_DOTFILES" = false ]; then
    if ! have gh; then
        echo ""
        echo -e "  ${YELLOW}gh not installed, skipping dotfiles sync.${NC}"
        echo -e "  ${YELLOW}Install gh first, then run: ${CYAN}gh auth login && chezmoi init git@github.com:cheparity/dotfiles.git && chezmoi apply${NC}"
    else
    echo ""
    echo -e "  ${YELLOW}Sync dotfiles? Requires GitHub auth.${NC}"
    echo -e "  ${YELLOW}On a temporary machine, choose n and run later:  gh auth login && chezmoi init cheparity && chezmoi apply${NC}"
    echo ""
    read -r -p "  Sync dotfiles? (y/n): " SYNC

    if [[ "$SYNC" =~ ^[Yy]$ ]]; then
        section "Phase 2: GitHub auth + dotfiles"

        # ---- gh auth ----
        echo ""
        echo -e "  ${CYAN}▸${NC} GitHub auth"
        if gh auth status &>/dev/null; then
            skip "Already logged in to GitHub"
        else
            gh auth login --hostname github.com --git-protocol ssh --web
            ok "GitHub login done"
        fi

        # ---- SSH key ----
        echo ""
        echo -e "  ${CYAN}▸${NC} SSH Key"
        if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
            skip "SSH key already exists"
        else
            ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "cheparity@gmail.com"
            ok "SSH key generated"
        fi
        # Upload to GitHub (non-fatal, may already exist)
        gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "$(hostname)-$(date +%Y%m%d)" 2>/dev/null \
            && ok "SSH key uploaded to GitHub" \
            || skip "SSH key may already exist on GitHub"

        # ---- chezmoi init + apply ----
        echo ""
        echo -e "  ${CYAN}▸${NC} chezmoi sync"
        if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
            skip "chezmoi repo already exists"
        else
            chezmoi init git@github.com:cheparity/dotfiles.git
            ok "chezmoi init done"
        fi
        chezmoi apply
        ok "chezmoi apply done"

        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}  Phase 2 done${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo ""
        echo -e "  ${YELLOW}Skipped dotfiles sync.${NC}"
        echo -e "  Run later: ${CYAN}gh auth login && chezmoi init git@github.com:cheparity/dotfiles.git && chezmoi apply${NC}"
    fi
    fi
fi

# =============================================================================
# Phase 3: agent tools
# =============================================================================

section "Phase 3: Agent tools (optional)"

echo ""
echo -e "  ${YELLOW}Install optional agent tools? (gh, omp)${NC}"
read -r -p "  Install agent tools? (y/n): " INSTALL_AGENTS

if [[ "$INSTALL_AGENTS" =~ ^[Yy]$ ]]; then
    # ---- gh-cli ----
    echo ""
    echo -e "  ${CYAN}▸${NC} GitHub CLI"
    if have gh; then
        skip "gh"
    else
        GH_VERSION=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | jq -r '.tag_name' | sed 's/^v//')
        curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH}.tar.gz" \
            | tar xz -C /tmp
        $SUDO mv "/tmp/gh_${GH_VERSION}_linux_${ARCH}/bin/gh" /usr/local/bin/gh
        rm -rf "/tmp/gh_${GH_VERSION}_linux_${ARCH}"
        ok "gh installed"
    fi

    # ---- omp ----
    echo ""
    echo -e "  ${CYAN}▸${NC} omp (AI coding agent)"
    if have omp; then
        skip "omp"
    else
        curl -fsSL https://omp.sh/install | sh
        ok "omp installed"
    fi
else
    echo ""
    echo -e "  ${YELLOW}Skipped agent tools.${NC}"
fi

# =============================================================================
# Done
# =============================================================================

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓  All done!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}source ~/.bashrc${NC}  to reload environment"
echo ""
echo -e "  Start omp:"
echo -e "  ${CYAN}omp${NC}"
echo ""
echo -e "  To install cpolar (reverse proxy):"
echo -e "  ${CYAN}curl -sL https://git.io/cpolar | sudo bash${NC}"
