# Iosevka customizer: https://typeof.net/Iosevka/customizer
# Nerd fonts cheat sheet: https://www.nerdfonts.com/cheat-sheet

# Default recipe: compile and install Iosevka font from scratch
default: clone build-fontcc-image compile-iosevka patch-nerd-font install

# Print latest stable upstream versions of Iosevka and Nerd Fonts
versions:
    #!/usr/bin/env bash
    set -euo pipefail
    NERD=$(git ls-remote --tags --refs https://github.com/ryanoasis/nerd-fonts.git \
        | sed 's|.*refs/tags/||' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
    echo "Iosevka:            $(just _iosevka-tag)"
    echo "Nerd Fonts:         $NERD"
    echo "nerdfonts/patcher:  $(just _patcher-tag)"

# Latest stable Iosevka release tag (vX.Y.Z, no pre-releases)
[private]
_iosevka-tag:
    #!/usr/bin/env bash
    set -euo pipefail
    TAG=$(git ls-remote --tags --refs https://github.com/be5invis/Iosevka.git \
        | sed 's|.*refs/tags/||' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
    [ -n "$TAG" ] || { echo "error: no stable Iosevka tag found" >&2; exit 1; }
    echo "$TAG"

# Highest numeric nerdfonts/patcher image tag on Docker Hub (X.Y.Z)
[private]
_patcher-tag:
    #!/usr/bin/env bash
    set -euo pipefail
    TAG=$(curl -fsS "https://hub.docker.com/v2/repositories/nerdfonts/patcher/tags?page_size=100&ordering=last_updated" \
        | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
    [ -n "$TAG" ] || { echo "error: no nerdfonts/patcher version tag found" >&2; exit 1; }
    echo "$TAG"

# Clone/update only Docker directory from Iosevka repo.
clone:
    #!/usr/bin/env bash
    set -euo pipefail
    TAG=$(just _iosevka-tag)
    echo "==> Iosevka: latest release is $TAG"
    if [ -d "Iosevka" ]; then
        git -C Iosevka fetch --depth 1 origin tag "$TAG"
        git -C Iosevka checkout "$TAG"
    else
        git clone --depth 1 --filter=blob:none --sparse --branch "$TAG" https://github.com/be5invis/Iosevka.git
        git -C Iosevka sparse-checkout set docker
    fi

# Build Docker image for Iosevka font compilation (no cache: refresh toolchain)
build-fontcc-image:
    docker build --pull --no-cache -t=fontcc Iosevka/docker

# Build Iosevka font distribution
compile-iosevka:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf dist/iosevka dist/iosevka-term
    TAG=$(just _iosevka-tag)
    echo "==> Using Iosevka $TAG"
    docker run --rm -v ${PWD}:/work -e "VERSION_TAG=$TAG" fontcc ttf-unhinted::iosevka ttf-unhinted::iosevka-term

# Patch fonts with Nerd Font glyphs
patch-nerd-font:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -f dist/*.ttf
    TAG=$(just _patcher-tag)
    echo "==> Using nerdfonts/patcher $TAG"
    docker run --rm -v ./dist/iosevka/TTF-Unhinted/:/in:Z -v ./dist:/out:Z nerdfonts/patcher:$TAG --complete --makegroups 4
    docker run --rm -v ./dist/iosevka-term/TTF-Unhinted/:/in:Z -v ./dist:/out:Z nerdfonts/patcher:$TAG --complete --makegroups 4

# Install font on macOS
install:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> Installing fonts..."
    rm -f ~/Library/Fonts/Iosevka*.ttf
    cp dist/*.ttf ~/Library/Fonts/
    echo "==> Fonts installed successfully"
