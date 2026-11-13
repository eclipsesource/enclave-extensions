#!/bin/bash
# Copyright (C) 2026 EclipseSource GmbH and others.
#
# This program and the accompanying materials are made available under the
# terms of the MIT License, which is available in the project root.
#
# SPDX-License-Identifier: MIT

# Install a pinned Google Workspace CLI (gws) release binary in the user tool
# prefix. Bump GWS_VERSION and both checksums together.
set -euo pipefail

GWS_VERSION=0.22.5
GWS_SHA256_X86_64=4db473dde4b1ab872e4ff35d769b0d4af1f1a6441a605e79d5cf8ada9c87e920
GWS_SHA256_AARCH64=e700fe63524932b10ec2130b47ece90aa850e66005fe52ccfc4cf8767bf9919a

case "$(uname -m)" in
    x86_64 | amd64)
        arch=x86_64
        sha256=$GWS_SHA256_X86_64
        ;;
    aarch64 | arm64)
        arch=aarch64
        sha256=$GWS_SHA256_AARCH64
        ;;
    *)
        echo "gws: unsupported architecture $(uname -m)" >&2
        exit 1
        ;;
esac

# The musl builds are statically linked, so they do not depend on the glibc
# version of the base image. The gnu builds need glibc 2.39.
asset="google-workspace-cli-${arch}-unknown-linux-musl.tar.gz"
url="https://github.com/googleworkspace/cli/releases/download/v${GWS_VERSION}/${asset}"

download_dir="$(mktemp -d)"
trap 'rm -rf "$download_dir"' EXIT

archive="$download_dir/$asset"
curl -fsSL --retry 3 -o "$archive" "$url"
if ! echo "${sha256}  ${archive}" | sha256sum -c --quiet -; then
    echo "gws: checksum mismatch for $asset" >&2
    exit 1
fi

tar -xzf "$archive" -C "$download_dir" ./gws
mkdir -p "$HOME/.local/bin"
install -m 0755 "$download_dir/gws" "$HOME/.local/bin/gws"

"$HOME/.local/bin/gws" --version >/dev/null
echo "gws ${GWS_VERSION} installed"
