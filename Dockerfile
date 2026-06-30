# Dockerfile for LMMS WebAssembly build environment
# Copyright (c) 2024 LMMS WASM contributors
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Builds Qt 5.15 for WASM and then LMMS on top of it.
#
# Usage:
#   docker build -t lmms-wasm-builder .
#   docker run --rm -v $(pwd):/workspace lmms-wasm-builder ./build-wasm.sh

FROM emscripten/emsdk:3.1.4

# Qt 5.15 source tarballs (hosted separately due to licensing)
# You must download these from https://download.qt.io/archive/qt/5.15/5.15.16/submodules/
# and place them in the build context:
#   qtbase-everywhere-opensource-src-5.15.16.tar.xz
#   qtsvg-everywhere-opensource-src-5.15.16.tar.xz
#   qtxmlpatterns-everywhere-opensource-src-5.15.16.tar.xz

ENV EMSDK=/emsdk
ENV EMSCRIPTEN=/emsdk/upstream/emscripten
ENV PATH="${EMSDK}:${EMSCRIPTEN}:${PATH}"

# System dependencies for Qt build
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    ninja-build \
    pkg-config \
    python3 \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Copy Qt source tarballs
COPY qtbase-everywhere-opensource-src-5.15.16.tar.xz \
     qtsvg-everywhere-opensource-src-5.15.16.tar.xz \
     qtxmlpatterns-everywhere-opensource-src-5.15.16.tar.xz \
     /workspace/

# Build Qt 5.15 for WASM
RUN mkdir -p /workspace/qt5-src /workspace/qt5-wasm && \
    cd /workspace/qt5-src && \
    tar xf /workspace/qtbase-everywhere-opensource-src-5.15.16.tar.xz && \
    tar xf /workspace/qtsvg-everywhere-opensource-src-5.15.16.tar.xz && \
    tar xf /workspace/qtxmlpatterns-everywhere-opensource-src-5.15.16.tar.xz && \
    cd qtbase-everywhere-src-5.15.16 && \
    ./configure \
        -xplatform wasm-emscripten \
        -confirm-license -opensource \
        -nomake examples -nomake tests \
        -no-feature-thread \
        -no-dbus \
        -no-ssl \
        -no-cups \
        -no-gui \
        -widgets \
        -prefix /workspace/qt5-wasm && \
    make -j$(nproc) && make install && \
    cd /workspace/qt5-src/qtsvg-everywhere-src-5.15.16 && \
    /workspace/qt5-wasm/bin/qmake && make -j$(nproc) && make install && \
    cd /workspace/qt5-src/qtxmlpatterns-everywhere-src-5.15.16 && \
    /workspace/qt5-wasm/bin/qmake && make -j$(nproc) && make install && \
    rm -rf /workspace/qt5-src /workspace/*.tar.xz

# Build LMMS dependencies (fftw3, libsndfile, libsamplerate)
# These are built from source with Emscripten
# Stub - prebuilt headers placed in wasm-deps/

COPY wasm-deps/ /workspace/wasm-deps/

CMD ["/bin/bash"]
