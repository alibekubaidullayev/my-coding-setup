# Shared by install.sh and collect.sh. Bash 3.2 compatible (macOS /bin/bash).

DOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_REPO="$(cd "$DOT_DIR/.." && pwd)"
OS="$(uname -s)"

is_mac() { [[ $OS == Darwin ]]; }
is_linux() { [[ $OS == Linux ]]; }

# lazygit reads its config from a different place on each OS
lazygit_dir() {
	if is_mac; then echo "Library/Application Support/lazygit"; else echo ".config/lazygit"; fi
}

# What the repo manages, one entry per line:
#   repo path (under dotfiles/) | target (under $HOME) | platforms | live path collect.sh reads, when it differs
# Karabiner is linked as a whole directory: it rewrites karabiner.json by replacing
# the file, which would break a file-level symlink.
manifest() {
	cat <<EOF
zsh/zshrc|.zshrc|all
zsh/zshenv|.zshenv|all
tmux/tmux.conf|.tmux.conf|all
bin/ta|.local/bin/ta|all
git/gitconfig|.gitconfig|all
ghostty/config|.config/ghostty/config|all|Library/Application Support/com.mitchellh.ghostty/config
ghostty/themes/lackluster|.config/ghostty/themes/lackluster|all
direnv/direnv.toml|.config/direnv/direnv.toml|all
direnv/direnvrc|.config/direnv/direnvrc|all
atuin/config.toml|.config/atuin/config.toml|all
lazygit/config.yml|$(lazygit_dir)/config.yml|all
karabiner|.config/karabiner|macos
EOF
}

applies() {
	case $1 in
	all) return 0 ;;
	macos) is_mac ;;
	linux) is_linux ;;
	*) return 1 ;;
	esac
}

# True when $1 is a symlink resolving to somewhere inside the repo
points_into_repo() {
	[[ -L $1 ]] || return 1
	local real
	real="$(cd "$(dirname "$1")" && cd "$(dirname "$(readlink "$1")")" 2>/dev/null && pwd)" || return 1
	case $real/ in "$DOT_DIR"/*) return 0 ;; esac
	return 1
}

if [[ -t 1 ]]; then
	_c_dim=$'\e[2m' _c_ok=$'\e[32m' _c_warn=$'\e[33m' _c_err=$'\e[31m' _c_b=$'\e[1m' _c_r=$'\e[0m'
else
	_c_dim='' _c_ok='' _c_warn='' _c_err='' _c_b='' _c_r=''
fi
step() { printf '\n%s==> %s%s\n' "$_c_b" "$*" "$_c_r"; }
info() { printf '    %s\n' "$*"; }
ok() { printf '    %s✓%s %s\n' "$_c_ok" "$_c_r" "$*"; }
skip() { printf '    %s· %s%s\n' "$_c_dim" "$*" "$_c_r"; }
warn() { printf '    %s! %s%s\n' "$_c_warn" "$*" "$_c_r"; }
die() {
	printf '%serror:%s %s\n' "$_c_err" "$_c_r" "$*" >&2
	exit 1
}
