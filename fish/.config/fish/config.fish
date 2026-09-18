# config.fish — read by every fish shell, interactive or not.
#
# The PATH block below is the important part and must stay outside the
# interactive guard: it is what makes `claude`, `wal` and `waypaper` resolve.
#
# Why it is needed at all, given env/.config/environment.d also sets PATH:
# /usr/bin/start-hyprland is a compiled binary, so it never sources ~/.profile,
# and environment.d is only applied at session start. A shell that fixes its own
# PATH works in the session you are in right now, on a fresh install before the
# first re-login, and in any compositor. The two are belt and braces.

# fish_add_path is idempotent and prepends, so repeated shells do not grow PATH.
if test -d $HOME/.local/bin
    fish_add_path --path $HOME/.local/bin
end

# Dev toolchains, installed per-user (no sudo): .NET SDK via dotnet-install.sh,
# Flutter as a git checkout of the stable channel.
if test -d $HOME/.dotnet
    set -gx DOTNET_ROOT $HOME/.dotnet
    set -gx DOTNET_CLI_TELEMETRY_OPTOUT 1
    fish_add_path --path $HOME/.dotnet $HOME/.dotnet/tools
end
if test -d $HOME/development/flutter/bin
    fish_add_path --path $HOME/development/flutter/bin
    # Flutter web looks for google-chrome; point it at Chromium instead.
    command -q chromium; and set -gx CHROME_EXECUTABLE (command -s chromium)
end

if not status is-interactive
    exit
end

# ----------------------------------------------------------------- behaviour
set -g fish_greeting                 # no banner on every new window
set -gx EDITOR nvim
set -gx VISUAL nvim

# Ptyxis sets TERM=xterm-256color; tell anything that asks that it is truecolor,
# which is what makes the pywal palette render exactly rather than quantised.
set -gx COLORTERM truecolor

# ------------------------------------------------------------------- aliases
alias ls 'ls --color=auto --group-directories-first'
alias ll 'ls -lh --color=auto --group-directories-first'
alias la 'ls -lha --color=auto --group-directories-first'
alias ..  'cd ..'
alias ... 'cd ../..'
alias g git
alias gs 'git status --short --branch'
alias gd 'git diff'
alias gl 'git log --oneline --graph --decorate -20'

# The dotfiles themselves, since this is what the shell is mostly used for.
alias dots 'cd ~/Nuketown/dotfiles'

# -------------------------------------------------------------------- prompt
#
# starship if it is installed, otherwise the fish_prompt function in
# functions/. Guarded rather than assumed: `starship init` on a missing binary
# leaves fish with no prompt at all, which is a miserable way to find out.
#
# `starship init fish | source` defines fish_prompt at startup, which takes
# precedence over the autoloaded functions/fish_prompt.fish — fish only
# consults that file when the function is not already defined. So the two
# coexist and the fallback needs no extra wiring.
#
# Its colours come from ~/.config/starship.toml, which names ANSI slots rather
# than hex, so the prompt follows the wallpaper through the Ptyxis palette.
if command -q starship
    starship init fish | source
end
