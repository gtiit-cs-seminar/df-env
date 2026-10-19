#!/usr/bin/env bash
# Opens VS Code inside the df-env container, with a folder mounted at
# /workspace. The folder doesn't need a devcontainer.json: works for any
# submission or repo. Requires Docker, VS Code with the "Dev Containers"
# extension, and the `code` command on the PATH.
#
# Usage:
#   ./open-vscode.sh [folder]          open VS Code (default: current folder)
#   ./open-vscode.sh --stop [folder]   remove that folder's container
#
# There is one container per folder, reused while it exists; the files live in
# the host folder, so removing the container loses nothing.
set -euo pipefail

IMAGE=${IMAGE:-ghcr.io/gtiit-cs-seminar/df-env:latest}

STOP=0
if [ "${1:-}" = "--stop" ]; then STOP=1; shift; fi

DIR=$(cd "${1:-.}" && pwd)
base=$(basename "$DIR")
hash=$(printf %s "$DIR" | shasum | cut -c1-6)
NAME="df-env-${base//[^A-Za-z0-9_.-]/-}-$hash"

if [ "$STOP" = 1 ]; then
    docker rm -f "$NAME"
    exit
fi

if ! command -v code >/dev/null; then
    echo "Can't find the 'code' command. In VS Code: F1 > \"Shell Command: Install 'code' command in PATH\"." >&2
    exit 1
fi

case "$(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null || echo none)" in
    true)  echo ">> Using container $NAME" ;;
    false) echo ">> Starting container $NAME"; docker start "$NAME" >/dev/null ;;
    *)     echo ">> Creating container $NAME with $DIR at /workspace"
           # df-env-vscode-server: VS Code's server and extensions
           # (~700 MB) are downloaded once and shared across containers.
           docker run -d --init --name "$NAME" -v "$DIR:/workspace" -w /workspace \
               -v df-env-vscode-server:/home/student/.vscode-server \
               "$IMAGE" sleep infinity >/dev/null ;;
esac

# VS Code identifies the container by a hex-encoded JSON.
HEX=$(printf '{"containerName":"/%s"}' "$NAME" | xxd -p | tr -d '\n')
code --folder-uri "vscode-remote://attached-container+${HEX}/workspace"

echo ">> Done. To remove the container: $0 --stop \"$DIR\""
