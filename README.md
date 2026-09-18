# dotfiles

Each top-level directory is a [GNU Stow](https://www.gnu.org/software/stow/)
package laid out relative to `$HOME`, so `hypr/.config/hypr/hyprland.conf` ends
up at `~/.config/hypr/hyprland.conf`.

## On a new machine

```sh
git clone <this repo> ~/Nuketown/dotfiles
cd ~/Nuketown/dotfiles
stow -t ~ hypr quickshell screensaver nvim zed
```

Stow refuses to overwrite files that already exist. If a package reports a
conflict, move the existing file out of the way and run it again, or use
`stow --adopt` to pull the existing file into the repo (then check `git diff`,
because adopting replaces the repo's version with the one on disk).

`eww` and `reference` are old/archived and don't need stowing.

## Packages

| package       | what it is                                                          |
|---------------|---------------------------------------------------------------------|
| `hypr`        | Hyprland, hyprlock, hypridle (screensaver at 3 min idle, screen off at 10 min) |
| `quickshell`  | the bar                                                             |
| `screensaver` | fullscreen terminal screensaver started by hypridle and the bar     |
| `nvim`        | Neovim                                                              |
| `zed`         | Zed, with the Neovim keys; `Space H` opens its cheatsheet. Stow it before Zed's first launch, or `~/.config/zed` exists and conflicts |
| `rofi`, `wal`, `waypaper` | launcher, pywal templates, wallpaper picker             |

## Things stow can't install

```sh
sudo pacman -S hyprland hypridle hyprlock hyprpaper quickshell alacritty \
               stow udisks2 libnotify cmatrix asciiquarium
paru -S waypaper cbonsai pipes.sh unimatrix-git

# TerminalTextEffects for the screensaver, kept out of the system Python
python3 -m venv ~/.local/share/screensaver/venv
~/.local/share/screensaver/venv/bin/pip install terminaltexteffects
ln -s ~/.local/share/screensaver/venv/bin/tte ~/.local/bin/tte
```

Machine-specific bits to check in `hyprland.conf`: the `monitor=` line and the
`$HOME/Nuketown/rustystore/rustystore.sh` binding.
