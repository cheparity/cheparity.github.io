#!/usr/bin/env bash
# =============================================================================
# bootstrap-dev-env.sh — Ubuntu 新机器一键安装开发环境
#
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/cheparity/cheparity.github.io/master/scripts/bootstrap-dev-env.sh | bash
#
# Phase 1 (零认证):  基础工具 + 开发运行时
# Phase 2 (需认证):  GitHub 认证 + chezmoi dotfiles
# Phase 3 (agent):   opencode web UI agent
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

section() { echo -e "\n${CYAN}==>${NC} ${CYAN}$1${NC}"; }
ok()      { echo -e "  ${GREEN}✓${NC} $1"; }
skip()    { echo -e "  ${YELLOW}○${NC} $1 (已安装, 跳过)"; }
warn()    { echo -e "  ${YELLOW}⚠${NC} $1"; }

have()    { command -v "$1" >/dev/null 2>&1; }

NO_DOTFILES=false
[[ "${1:-}" == "--no-dotfiles" ]] && NO_DOTFILES=true

# =============================================================================
# Phase 1: 基础工具 + 开发运行时（零认证）
# =============================================================================

section "Phase 1: 基础工具 + 开发运行时"

# ---- apt 依赖 ----
echo ""
echo -e "  ${CYAN}▸${NC} 系统依赖 (apt)"

sudo apt-get update -qq

APT_PKGS=(build-essential curl git tmux jq unzip p7zip-full)
TO_INSTALL=()
for pkg in "${APT_PKGS[@]}"; do
    dpkg -s "$pkg" &>/dev/null && skip "$pkg" || TO_INSTALL+=("$pkg")
done
if [ ${#TO_INSTALL[@]} -gt 0 ]; then
    sudo apt-get install -y -qq "${TO_INSTALL[@]}"
    ok "已安装: ${TO_INSTALL[*]}"
fi

# ---- Rust (rustup) ----
echo ""
echo -e "  ${CYAN}▸${NC} Rust (rustup → cargo)"
if have cargo; then
    skip "rust"
else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    . "$HOME/.cargo/env"
    ok "rust 安装完成"
fi

# ---- uv ----
echo ""
echo -e "  ${CYAN}▸${NC} uv (Python 包管理器)"
if have uv; then
    skip "uv"
else
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    ok "uv 安装完成"
fi

# ---- Bun ----
echo ""
echo -e "  ${CYAN}▸${NC} Bun (JavaScript 运行时)"
if have bun; then
    skip "bun"
else
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
    ok "bun 安装完成"
fi

# ---- chezmoi ----
echo ""
echo -e "  ${CYAN}▸${NC} chezmoi (dotfiles 管理器)"
if have chezmoi; then
    skip "chezmoi"
else
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
    ok "chezmoi 安装完成 (二进制就绪)"
fi

# ---- gh-cli ----
echo ""
echo -e "  ${CYAN}▸${NC} GitHub CLI"
if have gh; then
    skip "gh"
else
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg status=none
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq gh
    ok "gh 安装完成"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Phase 1 完成${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# =============================================================================
# Phase 2: GitHub 认证 + dotfiles
# =============================================================================

if [ "$NO_DOTFILES" = false ]; then
    echo ""
    echo -e "  ${YELLOW}是否同步 dotfiles? 需要 GitHub 认证。${NC}"
    echo -e "  ${YELLOW}临时机器选 n，之后手动:  gh auth login && chezmoi init cheparity && chezmoi apply${NC}"
    echo ""
    read -r -p "  同步 dotfiles? (y/n): " SYNC

    if [[ "$SYNC" =~ ^[Yy]$ ]]; then
        section "Phase 2: GitHub 认证 + dotfiles"

        # ---- gh auth ----
        echo ""
        echo -e "  ${CYAN}▸${NC} GitHub 认证"
        if gh auth status &>/dev/null; then
            skip "已登录 GitHub"
        else
            gh auth login --hostname github.com --git-protocol ssh --web
            ok "GitHub 登录完成"
        fi

        # ---- SSH key ----
        echo ""
        echo -e "  ${CYAN}▸${NC} SSH Key"
        if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
            skip "SSH key 已存在"
        else
            ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "cheparity@gmail.com"
            ok "SSH key 生成完成"
        fi
        # 上传到 GitHub（失败不致命，可能已存在）
        gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "$(hostname)-$(date +%Y%m%d)" 2>/dev/null \
            && ok "SSH key 已上传 GitHub" \
            || skip "SSH key 可能已存在于 GitHub"

        # ---- chezmoi init + apply ----
        echo ""
        echo -e "  ${CYAN}▸${NC} chezmoi sync"
        if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
            skip "chezmoi 仓库已存在"
        else
            chezmoi init git@github.com:cheparity/dotfiles.git
            ok "chezmoi init 完成"
        fi
        chezmoi apply
        ok "chezmoi apply 完成"

        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}  Phase 2 完成${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo ""
        echo -e "  ${YELLOW}跳过 dotfiles 同步。${NC}"
        echo -e "  稍后手动: ${CYAN}gh auth login && chezmoi init git@github.com:cheparity/dotfiles.git && chezmoi apply${NC}"
    fi
fi

# =============================================================================
# Phase 3: agent 工具
# =============================================================================

section "Phase 3: agent 工具 (paseo + opencode + oh-my-pi)"

bun install -g @getpaseo/cli opencode-ai @oh-my-pi/pi-coding-agent
bun pm -g trust opencode-ai 2>/dev/null || true
ok "agent 工具安装完成"

# =============================================================================
# 完成
# =============================================================================

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓  全部完成！${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}source ~/.bashrc${NC}  使环境生效"
echo ""
echo -e "  启动 paseo daemon:"
echo -e "  ${CYAN}paseo daemon start --web-ui${NC}"
echo ""
echo -e "  启动 opencode web UI (tmux 中运行):"
echo -e "  ${CYAN}tmux new -s opencode${NC}"
echo -e "  ${CYAN}opencode serve --port 5000 --hostname 0.0.0.0${NC}"
echo ""
echo -e "  如需安装 cpolar (内网穿透):"
echo -e "  ${CYAN}curl -sL https://git.io/cpolar | sudo bash${NC}"
