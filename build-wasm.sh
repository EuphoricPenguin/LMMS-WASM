#!/bin/bash
# Build LMMS for WebAssembly
# Copyright (c) 2024 LMMS WASM contributors
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Prerequisites:
#   - Emscripten SDK 3.1.4+ (source /path/to/emsdk/emsdk_env.sh)
#   - Qt 5.15 built for WASM (set QT5_WASM_PREFIX)
#   - LMMS source at the commit pinned in lmms-wasm.patch
#
# Usage:
#   export QT5_WASM_PREFIX=/path/to/qt5-wasm
#   export LMMS_SOURCE=/path/to/lmms
#   ./build-wasm.sh
#
# Output:
#   docs/lmms.wasm, docs/lmms.js, docs/lmms.html

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRIPT_DIR"
BUILD_DIR="${BUILD_DIR:-$REPO_DIR/build}"
OUTPUT_DIR="$REPO_DIR/docs"

QT5_WASM_PREFIX="${QT5_WASM_PREFIX:-$REPO_DIR/qt5-wasm}"
LMMS_SOURCE="${LMMS_SOURCE:-}"

# Detect LMMS source
if [ -z "$LMMS_SOURCE" ]; then
    if [ -d "$REPO_DIR/lmms" ]; then
        LMMS_SOURCE="$REPO_DIR/lmms"
    elif [ -d "$REPO_DIR/../lmms" ]; then
        LMMS_SOURCE="$(cd "$REPO_DIR/../lmms" && pwd)"
    else
        echo "ERROR: LMMS_SOURCE not set and no lmms/ directory found."
        echo "Clone LMMS and apply the WASM patch:"
        echo "  git clone https://github.com/LMMS/lmms.git"
        echo "  cd lmms && git checkout 45970566f"
        echo "  git apply ../lmms-wasm.patch"
        exit 1
    fi
fi

echo "=== LMMS WebAssembly Build ==="
echo "LMMS source: $LMMS_SOURCE"
echo "Qt5 WASM:    $QT5_WASM_PREFIX"
echo "Build dir:   $BUILD_DIR"
echo "Output dir:  $OUTPUT_DIR"

# Verify prerequisites
if [ ! -f "$QT5_WASM_PREFIX/lib/cmake/Qt5Core/Qt5CoreConfig.cmake" ]; then
    echo "ERROR: Qt5 WASM not found at $QT5_WASM_PREFIX"
    echo "Build Qt 5.15 for WASM first. See Dockerfile for instructions."
    exit 1
fi

if ! command -v emcc &>/dev/null; then
    echo "ERROR: emcc not found. Source emsdk_env.sh first."
    exit 1
fi

# Apply polyfill headers to LMMS source
echo "Applying WASM polyfill headers..."
cp "$REPO_DIR/src/polyfills/memory_resource" "$LMMS_SOURCE/include/memory_resource"
cp "$REPO_DIR/src/polyfills/ranges" "$LMMS_SOURCE/include/ranges"

# Apply the WASM patch if needed
if [ ! -f "$LMMS_SOURCE/include/AudioWeb.h" ]; then
    echo "Applying WASM patch..."
    cd "$LMMS_SOURCE"
    git apply --check "$REPO_DIR/lmms-wasm.patch" 2>/dev/null && \
        git apply "$REPO_DIR/lmms-wasm.patch" || \
        echo "Patch may already be applied or incompatible. Continuing..."
fi

# Copy AudioWeb source files if patch didn't apply them
cp "$REPO_DIR/src/AudioWeb.h" "$LMMS_SOURCE/include/AudioWeb.h"
cp "$REPO_DIR/src/AudioWeb.cpp" "$LMMS_SOURCE/src/core/audio/AudioWeb.cpp"

# Configure with CMake
echo "Configuring with CMake..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake "$LMMS_SOURCE" \
    -DCMAKE_TOOLCHAIN_FILE="$REPO_DIR/emscripten.toolchain.cmake" \
    -DCMAKE_CXX_COMPILER_LAUNCHER="$REPO_DIR/em++-wrapper.sh" \
    -DCMAKE_BUILD_TYPE=Release \
    -DWANT_QT5=ON \
    -GNinja

# Build
echo "Building..."
cmake --build . --target lmms -j$(nproc)

# Collect outputs
echo "Collecting outputs..."
mkdir -p "$OUTPUT_DIR"
cp lmms.wasm lmms.js "$OUTPUT_DIR/"

# Generate HTML wrapper with audio setup
cat > "$OUTPUT_DIR/index.html" << 'HTMLEOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>LMMS WebAssembly</title>
<style>
  html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #1a1a1a; }
  #status { color: #ccc; font-family: sans-serif; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); text-align: center; z-index: 10; pointer-events: none; }
  .spinner { width: 40px; height: 40px; border: 3px solid #555; border-top-color: #0af; border-radius: 50%; animation: spin 0.8s linear infinite; margin: 0 auto 12px; }
  @keyframes spin { to { transform: rotate(360deg); } }
  #qt-canvas { display: block; width: 100%; height: 100%; }
</style>
</head>
<body>
<div id="status"><div class="spinner"></div>Loading LMMS&hellip;</div>
<script>
  var Module = {
    noExitRuntime: true,
    canvas: (function() { var c = document.createElement('canvas'); c.id = 'qt-canvas'; document.body.appendChild(c); return c; })(),
    setStatus: function(text) {
      var s = document.getElementById('status');
      if (s) s.textContent = text || 'Running...';
      if (text === '') { var el = document.getElementById('status'); if (el) el.style.display = 'none'; }
    },
    onRuntimeInitialized: function() {},
    print: console.log.bind(console),
    printErr: console.error.bind(console),
  };
</script>
<script src="lmms.js"></script>
</body>
</html>
HTMLEOF

echo ""
echo "=== Build complete ==="
du -sh "$OUTPUT_DIR"/lmms.wasm "$OUTPUT_DIR"/lmms.js
echo "Output in: $OUTPUT_DIR"
echo ""
echo "To test locally:  cd $OUTPUT_DIR && python3 -m http.server 8000"
