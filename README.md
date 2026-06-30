**The following is an experimental port using DeepSeek V4 Pro and OpenHands to evaluate model performance.**

# LMMS WebAssembly

WebAssembly port of [LMMS](https://github.com/LMMS/lmms) (Linux MultiMedia Studio) — a
free, open-source digital audio workstation — running in the browser via Emscripten and
Qt 5 for WebAssembly.

This is a best-effort experimental port with the full Qt 5 GUI compiled to WebAssembly,
targeting browser-based audio synthesis through the Web Audio API.

## Quick Start (pre-built)

A pre-built release is available from the
[Releases](https://github.com/EuphoricPenguin/LMMS-WASM/releases) page. Download
`lmms-wasm-*.tar.gz`, extract it, and serve the directory with any HTTP server:

```bash
tar xzf lmms-wasm-*.tar.gz
cd lmms-wasm
python3 -m http.server 8000
```

Then open `http://localhost:8000/lmms.html` in a browser with WebAssembly support
(Chrome/Edge/Firefox recommended).

> **Note:** The WASM binary is ~20 MB. First load will take a moment while it downloads
> and compiles.

## Building from Source

### Prerequisites

- **Emscripten SDK** 3.1.x (tested with 3.1.4)
- **Qt 5.15.x** built for WebAssembly (static)
- **CMake** 3.28+
- **Dependencies:** libsndfile, libsamplerate, FFTW3 built for WASM

### Step 1: Emscripten SDK

```bash
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install 3.1.4
./emsdk activate 3.1.4
source emsdk_env.sh
```

### Step 2: Qt 5 for WebAssembly

Qt 5 must be built as a static library targeting wasm32-emscripten. This is the most
involved step. Key points:

- Use Qt 5.15.16 source
- Configure with `-static -no-thread -no-feature-thread` (single-threaded WASM)
- Build only the modules needed: qtbase (Core, Gui, Widgets, Xml) and qtsvg
- Fix `QMAKE_LFLAGS_NEW_DTAGS` in `qtbase/mkspecs/common/gcc-base-unix.conf` (set to empty)

### Step 3: LMMS Source Patches

Clone LMMS and apply the WASM compatibility patch:

```bash
git clone https://github.com/LMMS/lmms.git
cd lmms
git checkout master  # or any recent commit
git apply /path/to/lmms-wasm.patch
```

### Step 4: Build LMMS

```bash
mkdir build && cd build
source /path/to/emsdk/emsdk_env.sh

cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=/path/to/emscripten.toolchain.cmake \
  -DCMAKE_PREFIX_PATH="/path/to/qt5-wasm;/path/to/wasm-deps" \
  -DSndFile_DIR=/path/to/wasm-deps/lib/cmake/SndFile \
  -DCMAKE_CXX_FLAGS="-Wno-c++11-narrowing -DLMMS_HAVE_WEB_AUDIO" \
  -DCMAKE_EXE_LINKER_FLAGS="-s ALLOW_MEMORY_GROWTH=1 -s WASM=1 -s INITIAL_MEMORY=67108864 -lembind" \
  -DWANT_ALSA=OFF -DWANT_JACK=OFF -DWANT_OSS=OFF \
  -DWANT_PULSEAUDIO=OFF -DWANT_PORTAUDIO=OFF -DWANT_SDL=OFF \
  -DWANT_SOUNDIO=OFF -DWANT_SNDIO=OFF \
  -DWANT_VST=OFF -DWANT_LV2=OFF -DWANT_LADSPA=OFF -DWANT_CARLA=OFF \
  -DWANT_MP3LAME=OFF -DWANT_OGGVORBIS=OFF -DWANT_FLAC=OFF \
  -DWANT_STK=OFF -DWANT_CALF=OFF -DWANT_CAPS=OFF -DWANT_CMT=OFF \
  -DWANT_TAP=OFF -DWANT_SWH=OFF -DWANT_SF2=OFF -DWANT_GIG=OFF \
  -DWANT_WERROR=OFF -DWANT_QT6=OFF -DWANT_WINMM=OFF

# Strip unsupported linker flags from generated build files
find . -name "link.txt" -exec sed -i 's/-Wl,--enable-new-dtags//g' {} \;

make lmms -j$(nproc)
```

Output files are `lmms` (JS runtime) and `lmms.wasm` in the build directory.

## Architecture

The port uses:

- **Qt 5 for WebAssembly** — provides the full GUI toolkit (widgets, event loop, canvas
  rendering) compiled to WebAssembly, rendered into an HTML canvas element.
- **Web Audio API** (`AudioWeb.cpp`) — replaces ALSA/JACK/PulseAudio backends. An
  `AudioWorklet`-style callback (implemented via Emscripten's `EMSCRIPTEN_KEEPALIVE`) is
  called from JavaScript to fill audio buffers, which are routed to the browser's
  `AudioContext`.
- **No threads** — Qt thread model is simulated in single-threaded WASM mode. Named
  semaphores and shared memory are replaced with trivial stubs.

## Limitations

- **No plugin support** — VST, LV2, LADSPA, Carla, and other plugin hosts are disabled
  (WASM doesn't support dynamic loading of native code)
- **Limited audio formats** — Only WAV import/export via libsndfile
- **No MIDI hardware** — No ALSA/JACK/WinMM MIDI backends
- **Single-threaded** — No worker threads for DSP processing
- **Performance** — WebAssembly runs at ~50-70% of native speed, so complex projects may
  stutter
- **File I/O** — Uses Emscripten's virtual filesystem (MEMFS); files must be pre-loaded
  or uploaded

## License

GNU General Public License v2.0 — same as upstream LMMS.

---

*This port was created by an AI agent (OpenHands) on behalf of the user.*
