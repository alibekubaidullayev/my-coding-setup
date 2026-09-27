#!/usr/bin/env bash
# Copy this machine's live configs into the repo, so they can be committed.
#
#   dotfiles/collect.sh
#
# Files that install.sh already linked into the repo are skipped: editing them
# edits the repo directly, so there is nothing to collect. Review `git diff`
# before committing: collect copies files exactly as they are on this machine.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

step "Collecting configs into ${DOT_DIR/#$HOME/\~}"
while IFS='|' read -r repo target platforms live; do
	applies "$platforms" || continue
	dst="$DOT_DIR/$repo"
	if points_into_repo "$HOME/$target"; then
		skip "$repo (linked: already in the repo)"
		continue
	fi
	src="$HOME/$target"
	[[ -n ${live:-} && -e "$HOME/$live" ]] && src="$HOME/$live"
	if [[ ! -e $src ]]; then
		warn "$repo: nothing at ${src/#$HOME/\~}"
		continue
	fi
	mkdir -p "$(dirname "$dst")"
	if [[ -d $src ]]; then
		rsync -a --delete --exclude automatic_backups "$src/" "$dst/"
	else
		cp -p "$src" "$dst"
	fi
	ok "$repo  ←  ${src/#$HOME/\~}"
done < <(manifest)

# The repo's gitconfig carries no identity: that lives in ~/.gitconfig.local
if [[ -f $DOT_DIR/git/gitconfig ]] && grep -q '^\[user\]' "$DOT_DIR/git/gitconfig"; then
	warn "git/gitconfig has a [user] section: move it to ~/.gitconfig.local before committing"
fi

info ""
info "Next: cd ${NVIM_REPO/#$HOME/\~} && git diff -- dotfiles"
