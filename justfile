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
    rm -rf dist/iosevka dist/iosevka-term dist/BUILD-INFO
    TAG=$(just _iosevka-tag)
    echo "==> Using Iosevka $TAG"
    docker run --rm -v ${PWD}:/work -e "VERSION_TAG=$TAG" fontcc ttf-unhinted::iosevka ttf-unhinted::iosevka-term
    {
        echo "compiled_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "iosevka=$TAG"
        echo "build_plan_sha256=$(shasum -a 256 private-build-plans.toml | cut -d' ' -f1)"
        echo "fontcc_image=$(docker image inspect --format '{{{{.Id}}' fontcc)"
    } > dist/BUILD-INFO

# Patch fonts with Nerd Font glyphs
patch-nerd-font:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -f dist/*.ttf
    [ -f dist/BUILD-INFO ] || { echo "error: dist/BUILD-INFO missing; run 'just compile-iosevka' first" >&2; exit 1; }
    TAG=$(just _patcher-tag)
    echo "==> Using nerdfonts/patcher $TAG"
    docker run --rm -v ./dist/iosevka/TTF-Unhinted/:/in:Z -v ./dist:/out:Z nerdfonts/patcher:$TAG --complete --makegroups 4
    docker run --rm -v ./dist/iosevka-term/TTF-Unhinted/:/in:Z -v ./dist:/out:Z nerdfonts/patcher:$TAG --complete --makegroups 4
    NERD=$(strings dist/IosevkaNerdFont-Regular.ttf | awk '!v && match($0, /Nerd Fonts [0-9.]+/) { v = substr($0, RSTART + 11, RLENGTH - 11) } END { print v }')
    grep -vE '^(patched_at|nerdfonts|nerdfonts_patcher)=' dist/BUILD-INFO > dist/BUILD-INFO.tmp || true
    {
        echo "patched_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "nerdfonts=v$NERD"
        echo "nerdfonts_patcher=$(docker image inspect --format '{{{{index .RepoDigests 0}}' nerdfonts/patcher:$TAG)"
    } >> dist/BUILD-INFO.tmp
    mv dist/BUILD-INFO.tmp dist/BUILD-INFO

# Show versions of the last build and of the installed fonts
built:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> dist/BUILD-INFO"
    cat dist/BUILD-INFO 2>/dev/null || echo "(none)"
    echo "==> Embedded in installed fonts (name ID 5)"
    for f in ~/Library/Fonts/Iosevka*NerdFont-Regular.ttf; do
        [ -e "$f" ] || { echo "(none installed)"; break; }
        echo "$(basename "$f"): $(strings "$f" | awk '!v && /^Version [0-9]/ { v = $0 } END { print v }')"
    done

# Install font on macOS
install:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> Installing fonts..."
    rm -f ~/Library/Fonts/Iosevka*.ttf
    cp dist/*.ttf ~/Library/Fonts/
    echo "==> Fonts installed successfully"
