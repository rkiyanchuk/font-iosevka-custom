# Iosevka customizer: https://typeof.net/Iosevka/customizer
# Nerd fonts cheat sheet: https://www.nerdfonts.com/cheat-sheet

# Default recipe: compile and install Iosevka font from scratch
default: clone build-fontcc-image compile-iosevka patch-nerd-font install

# Print latest upstream versions of Iosevka and Nerd Fonts
versions:
    #!/usr/bin/env bash
    set -euo pipefail
    IOSEVKA_TAGS=$(git ls-remote --tags --sort=-version:refname https://github.com/be5invis/Iosevka.git)
    IOSEVKA=$(echo "$IOSEVKA_TAGS" | head -1 | sed 's/.*refs\/tags\///')
    NERD_TAGS=$(git ls-remote --tags --sort=-version:refname https://github.com/ryanoasis/nerd-fonts.git)
    NERD=$(echo "$NERD_TAGS" | head -1 | sed 's/.*refs\/tags\///')
    echo "Iosevka:    $IOSEVKA"
    echo "Nerd Fonts: $NERD"

# Clone/update only Docker directory from Iosevka repo.
clone:
    #!/usr/bin/env bash
    set -euo pipefail
    TAGS=$(git ls-remote --tags --sort=-version:refname https://github.com/be5invis/Iosevka.git)
    TAG=$(echo "$TAGS" | head -1 | sed 's/.*refs\/tags\///')
    echo "==> Iosevka: latest release is $TAG"
    if [ -d "Iosevka" ]; then
        git -C Iosevka fetch --depth 1 origin tag "$TAG"
        git -C Iosevka checkout "$TAG"
    else
        git clone --depth 1 --filter=blob:none --sparse --branch "$TAG" https://github.com/be5invis/Iosevka.git
        git -C Iosevka sparse-checkout set docker
    fi

# Build Docker image for Iosevka font compilation
build-fontcc-image:
    docker build -t=fontcc Iosevka/docker

# Build Iosevka font distribution
compile-iosevka:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf dist/iosevka dist/iosevka-term
    TAGS=$(git ls-remote --tags --sort=-version:refname https://github.com/be5invis/Iosevka.git)
    TAG=$(echo "$TAGS" | head -1 | sed 's/.*refs\/tags\///')
    echo "==> Using Iosevka $TAG"
    docker run --rm -v ${PWD}:/work -e "VERSION_TAG=$TAG" fontcc ttf-unhinted::iosevka ttf-unhinted::iosevka-term

# Patch fonts with Nerd Font glyphs
patch-nerd-font:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -f dist/*.ttf
    TAG=$(curl -s "https://hub.docker.com/v2/repositories/nerdfonts/patcher/tags?page_size=1&name=4" | grep -o '"name":"[0-9.]*"' | head -1 | cut -d'"' -f4)
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
