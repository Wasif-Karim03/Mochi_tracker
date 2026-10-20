#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
OUTPUT="${1:-.build/previews}"
if [[ $# -gt 0 ]]; then shift; fi
swift build
BIN_DIR="$(swift build --show-bin-path)"
MODULE_DIR="$BIN_DIR"
CORE_OBJECTS=("$BIN_DIR/CompanionCore.o")
if [[ ! -f "${CORE_OBJECTS[0]}" ]]; then
    MODULE_DIR="$BIN_DIR/Modules"
    CORE_OBJECTS=("$BIN_DIR/CompanionCore.build/"*.o)
fi
if [[ ! -f "${CORE_OBJECTS[0]}" ]]; then
    echo "Could not locate CompanionCore build objects in $BIN_DIR" >&2
    exit 1
fi
swiftc -I "$MODULE_DIR" "${CORE_OBJECTS[@]}" \
    Sources/TypingCompanion/CompanionView.swift \
    Sources/TypingCompanion/KeyboardScene.swift \
    scripts/render-previews.swift -o .build/RenderPreviews
.build/RenderPreviews "$BIN_DIR/TypingCompanion_TypingCompanion.bundle" "$OUTPUT" "$@"
