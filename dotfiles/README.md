# dotfiles

The terminal side of this setup: zsh, tmux, `ta`, Ghostty, Karabiner and the
tools they call. `install.sh` sets all of it up on a new macOS or Linux machine
(or a new user account), next to the nvim config this repo already is.

## New machine

```sh
git clone <this repo> ~/.config/nvim
~/.config/nvim/dotfiles/install.sh
```

The script installs:

1. System packages: Xcode Command Line Tools on macOS; zsh, build tools and a
   clipboard tool on Linux (apt, dnf, pacman or zypper).
2. Homebrew and the `Brewfile`: nvim, tmux, fzf, lazygit… plus Ghostty and
   Karabiner-Elements on macOS. Homebrew runs on Linux as well, so both systems
   get the same recent versions (`ta` needs fzf ≥ 0.61, the nvim config needs
   Neovim ≥ 0.12).
3. oh-my-zsh with zsh-autosuggestions and zsh-syntax-highlighting, plus the tmux
   plugins listed in `tmux.conf`.
4. Symlinks from `$HOME` into this folder (table below). Anything already there
   is moved to `~/.dotfiles-backup/<time>/`.
5. The nvim plugins pinned in `lazy-lock.json`, and zsh as the login shell.

It is safe to re-run: steps that are already done are skipped.

| Repo | Linked to |
|---|---|
| `zsh/zshrc`, `zsh/zshenv` | `~/.zshrc`, `~/.zshenv` |
| `tmux/tmux.conf` | `~/.tmux.conf` |
| `bin/ta` | `~/.local/bin/ta` |
| `git/gitconfig` | `~/.gitconfig` |
| `ghostty/` | `~/.config/ghostty/config`, `themes/lackluster` |
| `direnv/`, `atuin/` | `~/.config/direnv/…`, `~/.config/atuin/config.toml` |
| `lazygit/config.yml` | lazygit's config dir (differs between macOS and Linux) |
| `karabiner/` (macOS) | `~/.config/karabiner` |

Options: `--no-packages`, `--no-brew` (system packages only), `--no-nvim`,
`--git-name` / `--git-email`, `-y` (no prompts), `-n` / `--dry-run`.

### Still by hand

- **macOS:** open Karabiner-Elements once and allow its driver (System Settings →
  General → Login Items & Extensions) and Input Monitoring. After that, holding
  Caps Lock and pressing a key sends `Ctrl-b` plus that key in Ghostty.
- **Linux:** install Ghostty yourself (it isn't in Homebrew on Linux). The Caps
  Lock layer is macOS-only; `Ctrl-b` works everywhere.
- **Second macOS account:** Homebrew belongs to the first account, so the
  script skips packages and says which command that user should run.

## Per machine, not in the repo

- `~/.gitconfig.local`: git name and email. The script writes it, reusing the
  identity from the `~/.gitconfig` it replaces, or asking you for one.
- `~/.zshrc.local`: anything that only belongs on one machine. It is sourced at
  the end of `.zshrc`, just before the Ghostty `ta` auto-start.

## Changing things

On a machine where `install.sh` has run, the configs are symlinks into this
repo: edit them where they are, then commit and push. Other machines get the
change with `git pull`.

On a machine that hasn't been set up with `install.sh`, `collect.sh` copies the
live files into the repo. It copies them exactly as they are, so check
`git diff` before committing. The repo versions are the portable ones (guarded
paths, no git identity), and an unlinked machine's files usually aren't.
