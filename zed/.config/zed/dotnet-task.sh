#!/usr/bin/env bash
# dotnet-task.sh <build|test|run|watch> <directory>
#
# Backs the "dotnet: *" tasks in tasks.json (<leader>d in keymap.json), which
# is Zed's stand-in for VS Code's build / test / run commands.
#
# The obvious task, `dotnet build` in $ZED_WORKTREE_ROOT, does not work in a
# real repo: the root usually holds several .sln files (or none), and dotnet
# refuses with "found more than one project or solution file". dotnet also
# only looks in the current directory, never upwards. So this walks up from
# the directory of the file being edited to the first one holding a project
# or solution, and runs there -- "build what I am working on", the way the C#
# Dev Kit builds the project that owns the open file.
set -uo pipefail

me="dotnet-task"

usage() { echo "usage: $me <build|test|run|watch> <directory>" >&2; exit 2; }
[ $# -eq 2 ] || usage
verb="$1"
dir="$2"
case "$verb" in build | test | run | watch) ;; *) usage ;; esac
[ -d "$dir" ] || { echo "$me: not a directory: $dir" >&2; exit 2; }
command -v dotnet >/dev/null 2>&1 || { echo "$me: dotnet not on PATH" >&2; exit 1; }

has_target() {
    compgen -G "$1/*.csproj" >/dev/null || compgen -G "$1/*.fsproj" >/dev/null ||
        compgen -G "$1/*.sln" >/dev/null || compgen -G "$1/*.slnx" >/dev/null
}

d="$(cd "$dir" && pwd)"
while [ "$d" != "/" ] && ! has_target "$d"; do
    d="$(dirname "$d")"
done
if ! has_target "$d"; then
    echo "$me: no .csproj/.fsproj/.sln above $dir" >&2
    exit 1
fi

cd "$d" || exit 1
echo "$me: dotnet $verb in $d"
if [ "$verb" = "watch" ]; then
    exec dotnet watch run
fi
exec dotnet "$verb"
