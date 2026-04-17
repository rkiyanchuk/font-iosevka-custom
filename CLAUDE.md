# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository builds custom Iosevka fonts with Nerd Font patches. It uses Docker containers to compile fonts from a custom build plan configuration.

## Build Commands

```bash
just                    # Full build: clone, build image, compile fonts, patch with Nerd Fonts, install
just clone              # Sparse checkout of Iosevka docker/ directory only (fetches latest tag)
just build-fontcc-image # Build Docker image for font compilation
just compile-iosevka    # Compile Iosevka fonts using Docker (outputs to dist/*/TTF-Unhinted/)
just patch-nerd-font    # Patch compiled fonts with Nerd Font glyphs (outputs *.ttf to dist/)
just install            # Copy dist/*.ttf to ~/Library/Fonts/ (macOS only)
```

## Architecture

- `private-build-plans.toml` - Font customization configuration defining two font families:
  - `iosevka` (`spacing = "normal"`) - Normal spacing variant
  - `iosevka-term` (`spacing = "term"`) - Terminal spacing variant (narrower symbols)
  - Both inherit from SS14 (JetBrains-style) with `noCvSs = true` (character variant selectors not exported)

- `Iosevka/` - Sparse checkout containing only `docker/` for building the `fontcc` Docker image
- `dist/iosevka/TTF-Unhinted/` and `dist/iosevka-term/TTF-Unhinted/` - Raw compiled fonts (input for Nerd Font patcher)
- `dist/*.ttf` - Final Nerd Font-patched fonts, ready to install

## Key Resources

- [Iosevka Customizer](https://typeof.net/Iosevka/customizer) - Interactive tool for designing build plans
- [Nerd Fonts Cheat Sheet](https://www.nerdfonts.com/cheat-sheet) - Icon lookup reference
- [Custom Build Documentation](https://github.com/be5invis/Iosevka/blob/master/doc/custom-build.md) - Full options reference
