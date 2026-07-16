#!/usr/bin/env bash
# =============================================================================
# bootstrap-dev-env.sh — Ubuntu 新机器一键安装开发环境
#
# 用法:
#   ./bootstrap-dev-env.sh            # Phase 1 全部安装
#   ./bootstrap-dev-env.sh --no-dotfiles  # 跳过 dotfiles 同步提示
#
# Phase 1 (自动, 无需认证):
#   apt  → git, curl, tmux, jq, unzip, p7zip, build-essential
#   curl → rustup/cargo, uv, bun, chezmoi, gh-cli
# Phase 2 (可选, 需要 gh auth login):
#   gh auth + ssh-keygen + chezmoi init/apply
# =============================================================================

set -euo pipefail

# ---- 颜色 ----
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

section() { echo -e "\n${CYAN}==>${NC} ${CYAN}$1${NC}"; }
ok()      { echo -e "  ${GREEN}✓${NC} $1"; }
skip()    { echo -e "  ${YELLOW}○${NC} $1 (已安装, 跳过)"; }

have() { command -v "$1" >/dev/null 2>&1; }

NO_DOTFILES=false
[[ "${1:-}" == "--no-dotfiles" ]] && NO_DOTFILES=true

# =============================================================================
# Phase 1
# =============================================================================

# ---- apt 依赖 ----
section "系统依赖 (apt)"

sudo apt-get update -qq

APT_PKGS=(build-essential curl git tmux jq unzip p7zip-full)
TO_INSTALL=()
for pkg in "${APT_PKGS[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then skip "$pkg"; else TO_INSTALL+=("$pkg"); fi
done
if [ ${#TO_INSTALL[@]} -gt 0 ]; then
    sudo apt-get install -y -qq "${TO_INSTALL[@]}"
    ok "已安装: ${TO_INSTALL[*]}"
fi

# ---- Rust ----
section "Rust (rustup + cargo)"
if have cargo; then
    skip "rust"
else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    . "$HOME/.cargo/env"
    ok "rust 安装完成"
fi

# ---- uv ----
section "uv (Python 包管理器)"
if have uv; then
    skip "uv"
else
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    ok "uv 安装完成"
fi

# ---- Bun ----
section "Bun (JavaScript 运行时)"
if have bun; then
    skip "bun"
else
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
    ok "bun 安装完成"
fi

# ---- chezmoi ----
section "chezmoi (dotfiles 管理器)"
if have chezmoi; then
    skip "chezmoi"
else
    curl -fsSL https://git.io/chezmoi | sh -s -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
    ok "chezmoi 安装完成 (二进制就绪, 未 init)"
fi

# ---- gh-cli ----
section "GitHub CLI"
if have gh; then
    skip "gh"
else
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq gh
    ok "gh 安装完成"
fi

# =============================================================================
# Phase 2 (可选)
# =============================================================================

if [ "$NO_DOTFILES" = false ]; then
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Phase 1 完成 — 所有开发工具已安装${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  是否同步 dotfiles? 需要 GitHub 认证。"
    echo -e "  ${YELLOW}临时机器可以选 n，随时跳到下一步:  bash bootstrap-dev-env.sh --no-dotfiles${NC}"
    echo ""
    read -r -p "  同步 dotfiles? (y/n): " SYNC_DOTFILES

    if [[ "$SYNC_DOTFILES" =~ ^[Yy]$ ]]; then
        section "GitHub 认证"

        if gh auth status &>/dev/null; then
            skip "已登录 GitHub"
        else
            echo "  即将打开浏览器进行 GitHub 登录..."
            gh auth login --hostname github.com --git-protocol ssh --web
            ok "GitHub 登录完成"
        fi

        section "SSH Key 配置"
        if [ ! -f "$HOME/.ssh/id_ed25519.pub" ]; then
            ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "cheparity@gmail.com"
            ok "SSH key 生成完成"
        else
            skip "SSH key 已存在"
        fi

        if ! gh ssh-key list 2>/dev/null | grep -q "$(cat "$HOME/.ssh/id_ed25519.pub" | awk '{print $2}')"; then
            gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "$(hostname)-$(date +%Y%m%d)" || ok "(如果已添加过会报错, 忽略即可)"
            ok "SSH key 已上传到 GitHub"
        else
            skip "SSH key 已在 GitHub"
        fi

        section "chezmoi init + apply"
        if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
            skip "chezmoi 仓库已存在"
        else
            chezmoi init git@github.com:cheparity/dotfiles.git
            ok "chezmoi init 完成"
        fi

        chezmoi apply
        ok "chezmoi apply 完成"

        echo ""
        echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  ✓  全部完成!${NC}"
        echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "  ${CYAN}source ~/.bashrc${NC}  使环境生效"
    else
        echo ""
        echo -e "  ${CYAN}source ~/.bashrc${NC}  使环境生效"
        echo -e "  稍后同步:  ${CYAN}gh auth login && chezmoi init git@github.com:cheparity/dotfiles.git && chezmoi apply${NC}"
    fi
else
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✓  Phase 1 完成${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  ${CYAN}source ~/.bashrc${NC}  使环境生效"
fi
