#!/bin/bash
# Wrapper around em++ to strip unsupported flags from the linker command line.
# Removes: --enable-new-dtags, -lrt, -rdynamic, --export-dynamic
# Copyright (c) 2024 LMMS WASM contributors
# SPDX-License-Identifier: GPL-2.0-or-later

args=()
for arg in "$@"; do
    case "$arg" in
        -Wl,--enable-new-dtags|-Wl,--enable-new-dtags=*) continue ;;
        -lrt) continue ;;
        -rdynamic) continue ;;
        -Wl,--export-dynamic|--export-dynamic) continue ;;
        *) args+=("$arg") ;;
    esac
done

exec /workspace/emsdk/upstream/emscripten/em++ "${args[@]}"
