# A compact two-part prompt: where you are, and what git thinks.
#
# Every colour here is an ANSI palette index (cyan/blue/yellow/normal) rather
# than a hex value, which is the whole trick: the palette comes from Ptyxis,
# Ptyxis takes it from pywal, and pywal takes it from the wallpaper. So the
# prompt follows the wallpaper without knowing anything about it.
function fish_prompt
    set -l last_status $status

    # Directory, abbreviated to the last two components so a deep path does not
    # push the cursor to the middle of the screen.
    set -l cwd (prompt_pwd --dir-length=0 --full-length-dirs=2)

    set_color --bold cyan
    echo -n $cwd
    set_color normal

    # Branch and dirtiness, only inside a repository.
    if command -sq git; and git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set -l branch (git symbolic-ref --short HEAD 2>/dev/null; or git rev-parse --short HEAD 2>/dev/null)
        set_color yellow
        echo -n " $branch"
        if not git diff --quiet HEAD 2>/dev/null
            set_color red
            echo -n "*"
        end
        set_color normal
    end

    # The arrow turns red when the last command failed -- the only status
    # reporting that is worth the horizontal space.
    if test $last_status -ne 0
        set_color red
    else
        set_color blue
    end
    echo -n " ❯ "
    set_color normal
end
