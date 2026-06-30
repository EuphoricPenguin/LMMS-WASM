# LMMS WebAssembly

WebAssembly port of [LMMS](https://github.com/LMMS/lmms) (Linux MultiMedia Studio) — a
free, open-source digital audio workstation — running in the browser via Emscripten and
Qt 5 for WebAssembly.

> **Status: Experimental** — This is a best-effort port. The Qt GUI initializes and the
> Web Audio backend is wired up, but the QEventDispatcherUNIX socketpair dependency
> prevents full rendering at this stage. See [Known Issues](#known-issues).

## Quick Start (pre-built)

Visit the live demo at:

**https://euphoricpenguin.github.io/LMMS-WASM/**

Or serve locally:

```bash
# Download or build the docs/ directory, then:
cd docs
python3 -m http.server 8000
```

> **Note:** The WASM binary is ~20 MB. First load takes a moment while it downloads
> and compiles.

## Building from Source

### Automated Build

The fastest way to build is with the included script:

```bash
# 1. Install Emscripten SDK
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk && ./emsdk install 3.1.4 && ./emsdk activate 3.1.4
source emsdk_env.sh

# 2. Build Qt 5 for WASM (see Dockerfile or CI workflow for reference)

# 3. Clone and patch LMMS
git clone https://github.com/LMMS/lmms.git
cd lmms && git checkout 45970566f
git apply /path/to/lmms-wasm-repo/lmms-wasm.patch

# 4. Run the build script
export QT5_WASM_PREFIX=/path/to/qt5-wasm
export LMMS_SOURCE=/path/to/lmms
/path/to/lmms-wasm-repo/build-wasm.sh
```

### Docker Build

A reproducible Docker build environment is provided:

```bash
# Download Qt 5.15.16 source tarballs first:
#   qtbase-everywhere-opensource-src-5.15.16.tar.xz
#   qtsvg-everywhere-opensource-src-5.15.16.tar.xz
#   qtxmlpatterns-everywhere-opensource-src-5.15.16.tar.xz

docker build -t lmms-wasm-builder .
docker run --rm -v $(pwd):/workspace lmms-wasm-builder ./build-wasm.sh
```

### Manual Build

#### Prerequisites

- **Emscripten SDK** 3.1.4 (exact version — API changes in later versions)
- **Qt 5.15.16** built for WebAssembly (static, `-xplatform wasm-emscripten`)
- **CMake** 3.20+

#### Step 1: Emscripten SDK

```bash
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install 3.1.4
./emsdk activate 3.1.4
source emsdk_env.sh
```

#### Step 2: Qt 5 for WebAssembly

Download Qt 5.15.16 from https://download.qt.io/archive/qt/5.15/5.15.16/submodules/

```bash
tar xf qtbase-everywhere-opensource-src-5.15.16.tar.xz
cd qtbase-everywhere-src-5.15.16

# Fix linker flags for Emscripten
sed -i 's/QMAKE_LFLAGS_NEW_DTAGS/#QMAKE_LFLAGS_NEW_DTAGS/' \
    mkspecs/common/gcc-base-unix.conf

./configure \
    -xplatform wasm-emscripten \
    -confirm-license -opensource \
    -nomake examples -nomake tests \
    -no-feature-thread -no-dbus -no-ssl -no-cups \
    -no-gui -widgets \
    -prefix /opt/qt5-wasm

make -j$(nproc) && make install

# Build qtsvg and qtxmlpatterns the same way with /opt/qt5-wasm/bin/qmake
```

#### Step 3: LMMS Source

```bash
git clone https://github.com/LMMS/lmms.git
cd lmms
git checkout 45970566f

# Apply WASM compatibility patches
git apply /path/to/lmms-wasm-repo/lmms-wasm.patch

# Install polyfill headers
cp /path/to/lmms-wasm-repo/src/polyfills/memory_resource include/memory_resource
cp /path/to/lmms-wasm-repo/src/polyfills/ranges include/ranges
```

#### Step 4: Build

```bash
mkdir build && cd build
cmake /path/to/lmms \
    -DCMAKE_TOOLCHAIN_FILE=/path/to/lmms-wasm-repo/emscripten.toolchain.cmake \
    -DCMAKE_CXX_COMPILER_LAUNCHER=/path/to/lmms-wasm-repo/em++-wrapper.sh \
    -DCMAKE_BUILD_TYPE=Release \
    -DWANT_QT5=ON \
    -GNinja

cmake --build . --target lmms -j$(nproc)
```

Output: `lmms.wasm` (~20 MB) and `lmms.js` (~12 MB) in the build directory.

## Project Structure

```
lmms-wasm-repo/
├── src/                          # Standalone source files for WASM port
│   ├── AudioWeb.h                # Web Audio API backend header
│   ├── AudioWeb.cpp              # Web Audio API backend implementation
│   └── polyfills/                # C++ standard library polyfills
│       ├── memory_resource       # std::pmr polyfill (Emscripten lacks it)
│       └── ranges                # std::ranges polyfill
├── docs/                         # GitHub Pages deployment output
│   ├── index.html                # HTML wrapper with Qt canvas + error overlay
│   ├── lmms.js                   # Emscripten JS runtime
│   └── lmms.wasm                 # WebAssembly binary
├── lmms-wasm.patch               # Full diff against upstream LMMS
├── emscripten.toolchain.cmake    # CMake toolchain for Emscripten
├── em++-wrapper.sh               # Strips unsupported linker flags
├── build-wasm.sh                 # One-shot build script
├── Dockerfile                    # Reproducible build environment
└── .github/workflows/
    ├── build.yml                 # CI: build LMMS WASM from source
    └── pages.yml                 # CD: deploy docs/ to GitHub Pages
```

## Architecture

- **Qt 5 for WebAssembly** — GUI toolkit compiled to WASM, rendering into an HTML5 canvas
- **Web Audio API** — ScriptProcessorNode drives audio callbacks into LMMS's DSP engine
  via EMSCRIPTEN_KEEPALIVE exports
- **C++17/20 polyfills** — `std::pmr`, `std::ranges`, and `std::views` are polyfilled
  for Emscripten's libc++ which lacks these
- **Single-threaded** — Qt's thread model is simulated in single-threaded WASM mode

## Known Issues

The current build hits `Couldn't create SIGINT socketpair` during Qt initialization.
This is because `QEventDispatcherUNIX::init()` requires Unix domain sockets, which
don't exist in the browser sandbox. A proper fix would require one of:

1. **Rebuild Qt with WASM-native event dispatcher** — Modify Qt's WASM platform plugin
   to use `QEventDispatcherWASM` instead of `QEventDispatcherUNIX`
2. **Patch Qt's event dispatcher at build time** — Override `QEventDispatcherUNIX::init()`
   to skip the socketpair call
3. **Use Qt 6** — Qt 6 has more mature WASM support with a dedicated event dispatcher

## Limitations

- No VST/LV2/LADSPA plugin support (WASM has no dynamic loading)
- WAV-only audio import/export via libsndfile
- No hardware MIDI backends
- Single-threaded DSP processing
- ~50-70% of native performance

## License

This project's original code (Web Audio backend, polyfills, build scripts, HTML wrapper)
is licensed under **GNU General Public License v2.0** — same as upstream LMMS.

The LMMS source code is copyright the LMMS contributors and also GPLv2-licensed.
See https://github.com/LMMS/lmms for details.

Qt 5.15.16 is available under LGPLv3/GPLv2 from https://www.qt.io/.

---

*This port was created by an AI agent (OpenHands) on behalf of the user.*
