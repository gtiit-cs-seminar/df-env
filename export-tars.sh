#!/usr/bin/env bash
# Builds the image for each architecture and saves it as a tar.gz, to
# distribute it without a registry (shared drive, USB stick). One file per
# architecture: `docker load` of a multi-arch tar only works with the
# "containerd image store" enabled, so we keep them separate.
#
# Usage: ./export-tars.sh [output-dir]      (default: ./dist)
#
# Produces:
#   df-env-amd64.tar.gz   Windows, Linux, Intel Macs
#   df-env-arm64.tar.gz   Apple Silicon Macs (M1/M2/...), Linux ARM
#
# Load with:  docker load -i df-env-<arch>.tar.gz   (or `podman load -i ...`)
#
# The image is tagged with the same name .devcontainer/devcontainer.json uses,
# so VS Code finds it locally and doesn't try to pull it.
set -euo pipefail

IMAGE=${IMAGE:-ghcr.io/gtiit-cs-seminar/df-env:latest}
DIST=${1:-dist}
cd "$(dirname "$0")"
mkdir -p "$DIST"

for arch in amd64 arm64; do
    out="$DIST/df-env-$arch.tar.gz"
    echo ">> $arch -> $out"
    docker buildx build --platform "linux/$arch" -t "$IMAGE" --load .
    docker save "$IMAGE" | gzip -9 > "$out"
done

# Each --load overwrites the tag; leave it pointing at this machine's architecture.
docker build -q -t "$IMAGE" . > /dev/null

(cd "$DIST" && shasum -a 256 df-env-*.tar.gz > SHA256SUMS)
ls -lh "$DIST"
