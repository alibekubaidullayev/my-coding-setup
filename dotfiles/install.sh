#!/usr/bin/env bash
# Set up the whole nvim + tmux + zsh + ta + Ghostty flow on this machine.
#
#   git clone <this repo> ~/.config/nvim && ~/.config/nvim/dotfiles/install.sh
#
# Safe to re-run. Existing files are moved to ~/.dotfiles-backup/<time>/ before
# being replaced by symlinks into the repo, so edits on any machine are edits
# to the repo (commit + push, then `git pull` elsewhere).
#
# Options:
#   --no-packages        skip system packages and Homebrew
#   --no-brew            system packages only, skip Homebrew
#   --no-nvim            skip installing nvim plugins
#   --git-name NAME      identity for ~/.gitconfig.local (asked for when missing)
#   --git-email EMAIL
#   -y, --yes            never prompt (keeps the current login shell)
#   -n, --dry-run        print what would change, change nothing
set -euo pipefail
source "$(dirname "$0")/lib.sh"

PACKAGES=1 BREW_PKGS=1 NVIM=1 DRY=0 YES=0 GIT_NAME='' GIT_EMAIL=''
while [[ $# -gt 0 ]]; do
	case $1 in
	--no-packages) PACKAGES=0 ;;
	--no-brew) BREW_PKGS=0 ;;
	--no-nvim) NVIM=0 ;;
	--git-name) GIT_NAME=$2 && shift ;;
	--git-email) GIT_EMAIL=$2 && shift ;;
	-y | --yes) YES=1 ;;
	-n | --dry-run) DRY=1 ;;
	-h | --help)
		sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'
		exit 0
		;;
	*) die "unknown option: $1 (see --help)" ;;
	esac
	shift
done

BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
interactive() { [[ $YES == 0 && -t 0 ]]; }
run() {
	if [[ $DRY == 1 ]]; then
		info "[dry-run] $*"
	else
		"$@"
	fi
}
tilde() { echo "${1/#$HOME/\~}"; }
sudo_cmd() {
	if [[ $(id -u) == 0 ]]; then "$@"; else sudo "$@"; fi
}

# Move whatever is at $1 into the backup dir (keeping its path under $HOME)
backup() {
	local rel=${1#$HOME/}
	run mkdir -p "$(dirname "$BACKUP/$rel")"
	run mv "$1" "$BACKUP/$rel"
	info "backed up $(tilde "$1") → $(tilde "$BACKUP/$rel")"
}

link() { # link <repo path> <target under $HOME>
	local src="$DOT_DIR/$1" dst="$HOME/$2"
	[[ -e $src ]] || {
		warn "$1 missing from the repo"
		return
	}
	if points_into_repo "$dst"; then
		skip "$2"
		return
	fi
	[[ -e $dst || -L $dst ]] && backup "$dst"
	run mkdir -p "$(dirname "$dst")"
	run ln -s "$src" "$dst"
	ok "$(tilde "$dst") → $(tilde "$src")"
}

clone() { # clone <url> <dir>
	if [[ -d $2 ]]; then
		skip "$(tilde "$2")"
	else
		run git clone --quiet --depth 1 "$1" "$2"
		ok "$(tilde "$2")"
	fi
}

brew_bin() {
	local b
	for b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
		[[ -x $b ]] && echo "$b" && return
	done
	command -v brew || true
}

printf '%sSetting up from %s (%s)%s\n' "$_c_b" "$(tilde "$NVIM_REPO")" "$OS" "$_c_r"
[[ $DRY == 1 ]] && warn "dry run: nothing will change"

# ── the nvim config itself ─────────────────────────────────────────────────────
step "Neovim config"
if [[ $NVIM_REPO == "$HOME/.config/nvim" ]]; then
	skip "repo is ~/.config/nvim"
else
	dst="$HOME/.config/nvim"
	if [[ -L $dst && $(cd "$dst" && pwd -P) == "$(cd "$NVIM_REPO" && pwd -P)" ]]; then
		skip "~/.config/nvim → $(tilde "$NVIM_REPO")"
	else
		[[ -e $dst || -L $dst ]] && backup "$dst"
		run mkdir -p "$HOME/.config"
		run ln -s "$NVIM_REPO" "$dst"
		ok "~/.config/nvim → $(tilde "$NVIM_REPO")"
	fi
fi

# ── packages ───────────────────────────────────────────────────────────────────
if [[ $PACKAGES == 1 ]]; then
	step "System packages"
	if is_mac; then
		if xcode-select -p >/dev/null 2>&1; then
			skip "Xcode command line tools"
		else
			run xcode-select --install || true
			warn "finish the Command Line Tools install, then re-run this script"
			[[ $DRY == 1 ]] || exit 1
		fi
	else
		# zsh from the system (so it can be a login shell), build tools for Homebrew
		# and treesitter parsers, a clipboard tool for tmux copy mode
		if command -v apt-get >/dev/null; then
			run sudo_cmd apt-get update -qq
			run sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
				build-essential procps curl file git zsh unzip xclip wl-clipboard >/dev/null
		elif command -v dnf >/dev/null; then
			run sudo_cmd dnf install -y -q @development-tools procps-ng curl file git zsh unzip xclip wl-clipboard
		elif command -v pacman >/dev/null; then
			run sudo_cmd pacman -S --needed --noconfirm base-devel procps-ng curl file git zsh unzip xclip wl-clipboard
		elif command -v zypper >/dev/null; then
			run sudo_cmd zypper -q install -y -t pattern devel_basis
			run sudo_cmd zypper -q install -y procps curl file git zsh unzip xclip wl-clipboard
		else
			warn "unknown package manager: install git, curl, zsh, a C compiler and make yourself"
		fi
		ok "system packages"
	fi

	step "Homebrew packages"
	BREW=$(brew_bin)
	if [[ $BREW_PKGS == 0 ]]; then
		skip "Homebrew (--no-brew)"
	else
		if [[ -z $BREW ]]; then
			info "installing Homebrew"
			run env NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
			BREW=$(brew_bin)
		fi
		if [[ -z $BREW ]]; then
			[[ $DRY == 1 ]] && info "[dry-run] brew bundle --file $(tilde "$DOT_DIR/Brewfile")" ||
				warn "Homebrew not found after install: skipping packages"
		elif [[ ! -w $("$BREW" --prefix) ]]; then
			# e.g. a second macOS account: /opt/homebrew belongs to the first one
			warn "$("$BREW" --prefix) belongs to another user: ask them to run"
			warn "  brew bundle --file $DOT_DIR/Brewfile"
		else
			eval "$("$BREW" shellenv)"
			run "$BREW" bundle --no-upgrade --file "$DOT_DIR/Brewfile"
			ok "Brewfile"
		fi
	fi
fi
# brew's bin dir, for the steps below and on machines where it was just installed
BREW=$(brew_bin)
[[ -n $BREW ]] && eval "$("$BREW" shellenv)"

# ── zsh: oh-my-zsh + plugins ───────────────────────────────────────────────────
step "oh-my-zsh"
command -v git >/dev/null || die "git is required (run without --no-packages)"
clone https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
clone https://github.com/zsh-users/zsh-autosuggestions.git "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

# ── git identity (kept out of the repo) ─────────────────────────────────────────
step "Git identity (~/.gitconfig.local)"
if [[ -f $HOME/.gitconfig.local ]] && git config -f "$HOME/.gitconfig.local" user.email >/dev/null; then
	skip "$(git config -f "$HOME/.gitconfig.local" user.name) <$(git config -f "$HOME/.gitconfig.local" user.email)>"
else
	# Carry over the identity from the ~/.gitconfig about to be replaced
	[[ -z $GIT_NAME ]] && GIT_NAME=$(git config --global user.name 2>/dev/null || true)
	[[ -z $GIT_EMAIL ]] && GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)
	if interactive; then
		[[ -z $GIT_NAME ]] && read -r -p "    git user.name: " GIT_NAME
		[[ -z $GIT_EMAIL ]] && read -r -p "    git user.email: " GIT_EMAIL
	fi
	if [[ -n $GIT_NAME && -n $GIT_EMAIL ]]; then
		run git config -f "$HOME/.gitconfig.local" user.name "$GIT_NAME"
		run git config -f "$HOME/.gitconfig.local" user.email "$GIT_EMAIL"
		ok "$GIT_NAME <$GIT_EMAIL>"
	else
		warn "no identity: re-run with --git-name / --git-email"
	fi
fi

# ── dotfiles ───────────────────────────────────────────────────────────────────
step "Linking configs"
while IFS='|' read -r repo target platforms _live; do
	applies "$platforms" && link "$repo" "$target"
done < <(manifest)
if is_mac; then
	# Ghostty on macOS also reads this file, after ~/.config/ghostty/config: move it
	# out of the way so the repo's config is the one that applies
	appsupport="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
	[[ -f $appsupport && ! -L $appsupport ]] && backup "$appsupport"
fi

# ── tmux plugins ───────────────────────────────────────────────────────────────
step "tmux plugins"
# Clone what tmux.conf lists instead of running tpm's installer: that needs a tmux
# server, and tmux-continuum would restore saved sessions into it
grep -E "^set(-option)? +-g +@plugin +" "$DOT_DIR/tmux/tmux.conf" | sed -E "s/.*@plugin +['\"]?([^'\" ]+)['\"]?.*/\1/" |
	while read -r plugin; do
		clone "https://github.com/$plugin.git" "$HOME/.tmux/plugins/${plugin##*/}"
	done

# ── nvim plugins ───────────────────────────────────────────────────────────────
if [[ $NVIM == 1 ]]; then
	step "Neovim plugins"
	if command -v nvim >/dev/null; then
		# lazy-lock.json pins every plugin: restore installs exactly those versions
		run nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 && ok "plugins at lazy-lock.json versions" ||
			warn "Lazy restore failed: open nvim and run :Lazy restore"
		info "treesitter parsers and LSP servers install on first launch"
	else
		warn "nvim not found: skipped"
	fi
fi

# ── login shell ────────────────────────────────────────────────────────────────
step "Login shell"
ZSH_BIN=$(command -v zsh || true)
if [[ -z $ZSH_BIN ]]; then
	warn "zsh not installed"
elif [[ $(basename "${SHELL:-}") == zsh ]]; then
	skip "already zsh"
elif interactive; then
	grep -qx "$ZSH_BIN" /etc/shells || echo "$ZSH_BIN" | run sudo_cmd tee -a /etc/shells >/dev/null
	run chsh -s "$ZSH_BIN" && ok "login shell → $ZSH_BIN" || warn "chsh failed: run  chsh -s $ZSH_BIN"
else
	warn "login shell is ${SHELL:-unknown}: run  chsh -s $ZSH_BIN"
fi

# ── what's left by hand ────────────────────────────────────────────────────────
step "Done"
[[ -d $BACKUP ]] && info "replaced files are in $(tilde "$BACKUP")"
if is_mac; then
	info "Karabiner (Caps Lock + key = tmux prefix): open Karabiner-Elements once and allow"
	info "  its driver (Login Items & Extensions) and Input Monitoring for karabiner_grabber."
	info "Open Ghostty: new windows start the ta picker."
else
	info "Ghostty is not in Homebrew on Linux: https://ghostty.org/docs/install/binary"
	info "The Caps Lock layer is macOS-only (Karabiner); tmux's Ctrl-b works everywhere."
fi
info "Start a new shell (or: exec zsh) to pick everything up."
