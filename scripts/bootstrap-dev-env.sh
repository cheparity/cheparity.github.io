#!/usr/bin/env bash
# =============================================================================
# bootstrap-dev-env.sh — One-click dev environment setup
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/cheparity/cheparity.github.io/master/scripts/bootstrap-dev-env.sh | bash
#
# Phase 1: Base tools + dev runtimes (package manager preferred)
# Phase 2: Neovim ecosystem (fonts, tree-sitter, fzf-lua deps)
# Phase 3: GitHub CLI + chezmoi dotfiles (interactive)
# Phase 4: Bun + agent tools
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

# Architecture detection
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH=amd64 ;;
    aarch64) ARCH=arm64 ;;
    *)       warn "Unrecognized arch $ARCH, defaulting to amd64"; ARCH=amd64 ;;
esac

# =============================================================================
# Package manager detection: brew -> apt -> dnf
# =============================================================================

PKG_MGR=""
if have brew; then
    PKG_MGR="brew"
elif have apt-get; then
    PKG_MGR="apt"
elif have dnf; then
    PKG_MGR="dnf"
else
    warn "No supported package manager found (brew/apt/dnf)"
fi

pkg_install() {
    case "$PKG_MGR" in
        brew) brew install "$@" ;;
        apt)  $SUDO apt-get install -y -qq "$@" ;;
        dnf)  $SUDO dnf install -y -q "$@" ;;
        *)    return 1 ;;
    esac
}

# =============================================================================
# Phase 1: Base tools + dev runtimes
# =============================================================================

section "Phase 1: Base tools + dev runtimes"

# ---- System dependencies ----
echo ""
echo -e "  ${CYAN}▸${NC} System dependencies"
if [ "$PKG_MGR" = "apt" ]; then
    $SUDO apt-get update -qq
    APT_PKGS=(build-essential curl git tmux unzip p7zip-full)
    TO_INSTALL=()
    for pkg in "${APT_PKGS[@]}"; do
        dpkg -s "$pkg" &>/dev/null && skip "$pkg" || TO_INSTALL+=("$pkg")
    done
    if [ ${#TO_INSTALL[@]} -gt 0 ]; then
        pkg_install "${TO_INSTALL[@]}"
        ok "Installed: ${TO_INSTALL[*]}"
    fi
elif [ "$PKG_MGR" = "dnf" ]; then
    DNF_PKGS=(gcc gcc-c++ make curl git tmux unzip)
    TO_INSTALL=()
    for pkg in "${DNF_PKGS[@]}"; do
        rpm -q "$pkg" &>/dev/null && skip "$pkg" || TO_INSTALL+=("$pkg")
    done
    if [ ${#TO_INSTALL[@]} -gt 0 ]; then
        pkg_install "${TO_INSTALL[@]}"
        ok "Installed: ${TO_INSTALL[*]}"
    fi
elif [ "$PKG_MGR" = "brew" ]; then
    BREW_PKGS=(curl git tmux unzip p7zip)
    TO_INSTALL=()
    for pkg in "${BREW_PKGS[@]}"; do
        brew list "$pkg" &>/dev/null && skip "$pkg" || TO_INSTALL+=("$pkg")
    done
    if [ ${#TO_INSTALL[@]} -gt 0 ]; then
        pkg_install "${TO_INSTALL[@]}"
        ok "Installed: ${TO_INSTALL[*]}"
    fi
else
    warn "No package manager, skipping system dependencies"
fi

# ---- jq ----
echo ""
echo -e "  ${CYAN}▸${NC} jq (JSON processor)"
if have jq; then
    skip "jq"
elif [ -n "$PKG_MGR" ]; then
    pkg_install jq
    ok "jq installed (package manager)"
else
    curl -fsSL "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-${ARCH}" \
        -o /tmp/jq
    chmod +x /tmp/jq
    $SUDO mv /tmp/jq /usr/local/bin/jq
    ok "jq installed (binary)"
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

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Phase 1 done${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# =============================================================================
# Phase 2: Neovim ecosystem
# =============================================================================

section "Phase 2: Neovim ecosystem"

# ---- Neovim ----
echo ""
echo -e "  ${CYAN}▸${NC} Neovim (>= 0.11.2, LuaJIT)"
if have nvim; then
    skip "nvim"
elif [ -n "$PKG_MGR" ]; then
    pkg_install neovim
    ok "nvim installed (package manager)"
else
    NVIM_ARCH=$([ "$ARCH" = "amd64" ] && echo x86_64 || echo arm64)
    NVIM_VERSION=$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest | jq -r '.tag_name')
    curl -fsSL "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-${NVIM_ARCH}.tar.gz" \
        | $SUDO tar xz -C /opt
    $SUDO ln -sf /opt/nvim-linux-${NVIM_ARCH}/bin/nvim /usr/local/bin/nvim
    ok "nvim installed (binary)"
fi

# ---- Nerd Fonts ----
echo ""
echo -e "  ${CYAN}▸${NC} Nerd Fonts (JetBrainsMono + Iosevka, optional)"
if [ "$PKG_MGR" = "brew" ]; then
    for FONT in font-jetbrains-mono-nerd-font font-iosevka-nerd-font; do
        if brew list --cask "$FONT" &>/dev/null; then
            skip "$FONT"
        else
            brew install --cask "$FONT"
            ok "$FONT installed"
        fi
    done
else
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
fi

# ---- tree-sitter-cli ----
echo ""
echo -e "  ${CYAN}▸${NC} tree-sitter-cli (nvim-treesitter)"
if have tree-sitter; then
    skip "tree-sitter"
elif [ "$PKG_MGR" = "brew" ]; then
    pkg_install tree-sitter
    ok "tree-sitter installed (brew)"
else
    TS_ARCH=$([ "$ARCH" = "amd64" ] && echo x64 || echo arm64)
    TS_VERSION=$(curl -fsSL https://api.github.com/repos/tree-sitter/tree-sitter/releases/latest | jq -r '.tag_name')
    curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/download/${TS_VERSION}/tree-sitter-cli-linux-${TS_ARCH}.zip" \
        -o /tmp/tree-sitter-cli.zip
    unzip -o /tmp/tree-sitter-cli.zip -d /tmp/tree-sitter-cli
    $SUDO mv /tmp/tree-sitter-cli/tree-sitter /usr/local/bin/tree-sitter
    rm -rf /tmp/tree-sitter-cli /tmp/tree-sitter-cli.zip
    ok "tree-sitter-cli installed (binary)"
fi

# ---- lazygit ----
echo ""
echo -e "  ${CYAN}▸${NC} lazygit (optional)"
if have lazygit; then
    skip "lazygit"
elif [ "$PKG_MGR" = "brew" ]; then
    pkg_install lazygit
    ok "lazygit installed (brew)"
else
    LG_ARCH=$([ "$ARCH" = "amd64" ] && echo x86_64 || echo arm64)
    LG_VERSION=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | jq -r '.tag_name' | sed 's/^v//')
    curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LG_VERSION}/lazygit_${LG_VERSION}_Linux_${LG_ARCH}.tar.gz" \
        | tar xz -C /tmp lazygit
    $SUDO mv /tmp/lazygit /usr/local/bin/lazygit
    ok "lazygit installed (binary)"
fi

# ---- fzf ----
echo ""
echo -e "  ${CYAN}▸${NC} fzf (fzf-lua, optional)"
if have fzf; then
    skip "fzf"
elif [ -n "$PKG_MGR" ]; then
    pkg_install fzf
    ok "fzf installed (package manager)"
else
    FZF_VERSION=$(curl -fsSL https://api.github.com/repos/junegunn/fzf/releases/latest | jq -r '.tag_name' | sed 's/^v//')
    curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_${ARCH}.tar.gz" \
        | tar xz -C /tmp
    $SUDO mv /tmp/fzf /usr/local/bin/fzf
    ok "fzf installed (binary)"
fi

# ---- ripgrep ----
echo ""
echo -e "  ${CYAN}▸${NC} ripgrep (fzf-lua live grep)"
if have rg; then
    skip "ripgrep"
elif [ "$PKG_MGR" = "apt" ]; then
    pkg_install ripgrep
    ok "ripgrep installed (apt)"
elif [ -n "$PKG_MGR" ]; then
    pkg_install ripgrep
    ok "ripgrep installed (package manager)"
else
    RG_ARCH=$([ "$ARCH" = "amd64" ] && echo x86_64 || echo aarch64)
    RG_VERSION=$(curl -fsSL https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | jq -r '.tag_name')
    curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/ripgrep-${RG_VERSION}-${RG_ARCH}-unknown-linux-musl.tar.gz" \
        | tar xz -C /tmp
    $SUDO mv "/tmp/ripgrep-${RG_VERSION}-${RG_ARCH}-unknown-linux-musl/rg" /usr/local/bin/rg
    rm -rf "/tmp/ripgrep-${RG_VERSION}-${RG_ARCH}-unknown-linux-musl"
    ok "ripgrep installed (binary)"
fi

# ---- fd ----
echo ""
echo -e "  ${CYAN}▸${NC} fd (fzf-lua find files)"
if have fd || have fdfind; then
    skip "fd"
elif [ "$PKG_MGR" = "apt" ]; then
    pkg_install fd-find
    ok "fd installed (apt, binary: fdfind)"
elif [ "$PKG_MGR" = "dnf" ]; then
    pkg_install fd-find
    ok "fd installed (dnf)"
elif [ "$PKG_MGR" = "brew" ]; then
    pkg_install fd
    ok "fd installed (brew)"
else
    FD_ARCH=$([ "$ARCH" = "amd64" ] && echo x86_64 || echo aarch64)
    FD_VERSION=$(curl -fsSL https://api.github.com/repos/sharkdp/fd/releases/latest | jq -r '.tag_name')
    curl -fsSL "https://github.com/sharkdp/fd/releases/download/${FD_VERSION}/fd-${FD_VERSION}-${FD_ARCH}-unknown-linux-gnu.tar.gz" \
        | tar xz -C /tmp
    $SUDO mv "/tmp/fd-${FD_VERSION}-${FD_ARCH}-unknown-linux-gnu/fd" /usr/local/bin/fd
    rm -rf "/tmp/fd-${FD_VERSION}-${FD_ARCH}-unknown-linux-gnu"
    ok "fd installed (binary)"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Phase 2 done${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# =============================================================================
# Phase 3: GitHub CLI + chezmoi dotfiles
# =============================================================================

section "Phase 3: GitHub CLI + dotfiles"

# ---- gh-cli ----
echo ""
echo -e "  ${CYAN}▸${NC} GitHub CLI"
if have gh; then
    skip "gh"
elif [ "$PKG_MGR" = "brew" ]; then
    pkg_install gh
    ok "gh installed (brew)"
elif [ "$PKG_MGR" = "dnf" ]; then
    pkg_install gh
    ok "gh installed (dnf)"
else
    GH_VERSION=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | jq -r '.tag_name' | sed 's/^v//')
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH}.tar.gz" \
        | tar xz -C /tmp
    $SUDO mv "/tmp/gh_${GH_VERSION}_linux_${ARCH}/bin/gh" /usr/local/bin/gh
    rm -rf "/tmp/gh_${GH_VERSION}_linux_${ARCH}"
    ok "gh installed (binary)"
fi

# ---- GitHub auth ----
echo ""
echo -e "  ${CYAN}▸${NC} GitHub auth"
if gh auth status &>/dev/null; then
    skip "Already logged in to GitHub"
else
    echo -e "  ${YELLOW}Login to GitHub? (needed for dotfiles sync and SSH key upload)${NC}"
    read -r -p "  Login to GitHub? (y/n): " GH_LOGIN

    if [[ "$GH_LOGIN" =~ ^[Yy]$ ]]; then
        gh auth login --hostname github.com --git-protocol ssh --web
        ok "GitHub login done"
    else
        echo -e "  ${YELLOW}Skipped GitHub login. Run later: ${CYAN}gh auth login${NC}"
    fi
fi

# ---- SSH key (only if authenticated) ----
if gh auth status &>/dev/null; then
    echo ""
    echo -e "  ${CYAN}▸${NC} SSH Key"
    if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
        skip "SSH key already exists"
    else
        ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "cheparity@gmail.com"
        ok "SSH key generated"
    fi
    gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "$(hostname)-$(date +%Y%m%d)" 2>/dev/null \
        && ok "SSH key uploaded to GitHub" \
        || skip "SSH key may already exist on GitHub"
fi

# ---- chezmoi ----
echo ""
echo -e "  ${CYAN}▸${NC} chezmoi (dotfiles manager)"
if have chezmoi; then
    skip "chezmoi"
elif [ "$PKG_MGR" = "brew" ]; then
    pkg_install chezmoi
    ok "chezmoi installed (brew)"
else
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
    ok "chezmoi installed"
fi

# ---- dotfiles sync ----
echo ""
echo -e "  ${YELLOW}Sync dotfiles via chezmoi?${NC}"
echo -e "  ${YELLOW}Requires GitHub auth. On a temporary machine, choose n.${NC}"
read -r -p "  Sync dotfiles? (y/n): " SYNC

if [[ "$SYNC" =~ ^[Yy]$ ]]; then
    if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
        skip "chezmoi repo already exists"
    else
        chezmoi init git@github.com:cheparity/dotfiles.git
        ok "chezmoi init done"
    fi
    chezmoi apply
    ok "chezmoi apply done"
else
    echo ""
    echo -e "  ${YELLOW}Skipped. Run later: ${CYAN}chezmoi init git@github.com:cheparity/dotfiles.git && chezmoi apply${NC}"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Phase 3 done${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# =============================================================================
# Phase 4: Bun + agent tools
# =============================================================================

section "Phase 4: Bun + agent tools"

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

# ---- Agent tools (via bun) ----
echo ""
echo -e "  ${CYAN}▸${NC} Agent tools (omp)"
bun install -g @oh-my-pi/pi-coding-agent
bun pm -g trust @oh-my-pi/pi-coding-agent 2>/dev/null || true
ok "omp installed (bun)"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Phase 4 done${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

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
