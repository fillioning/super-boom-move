#!/usr/bin/env bash
# Build Super Boom module for Schwung (ARM64)
#
# Automatically uses Docker for cross-compilation if needed.
# Set CROSS_PREFIX to skip Docker (e.g., for native ARM builds).
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGE_NAME="schwung-builder"

# Check if we need Docker
if [ -z "$CROSS_PREFIX" ] && [ ! -f "/.dockerenv" ]; then
    echo "=== Super Boom Module Build (via Docker) ==="
    echo ""

    # Convert to Windows paths for Docker on MINGW
    if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
        DOCKER_REPO_ROOT="$(cygpath -w "$REPO_ROOT")"
        DOCKER_DOCKERFILE="$(cygpath -w "$SCRIPT_DIR/Dockerfile")"
    else
        DOCKER_REPO_ROOT="$REPO_ROOT"
        DOCKER_DOCKERFILE="$SCRIPT_DIR/Dockerfile"
    fi

    # Build Docker image if needed
    if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
        echo "Building Docker image (first time only)..."
        MSYS_NO_PATHCONV=1 docker build -t "$IMAGE_NAME" -f "$DOCKER_DOCKERFILE" "$DOCKER_REPO_ROOT"
        echo ""
    fi

    # Run build inside container
    echo "Running build..."
    MSYS_NO_PATHCONV=1 docker run --rm \
        -v "$DOCKER_REPO_ROOT:/build" \
        -w /build \
        "$IMAGE_NAME" \
        ./scripts/build.sh

    echo ""
    echo "=== Done ==="
    exit 0
fi

# === Actual build (runs in Docker or with cross-compiler) ===
CROSS_PREFIX="${CROSS_PREFIX:-aarch64-linux-gnu-}"

cd "$REPO_ROOT"

echo "=== Building Super Boom Module ==="
echo "Cross prefix: $CROSS_PREFIX"

# Create build directories
mkdir -p build
mkdir -p dist/superboom

# Compile DSP plugin (with aggressive optimizations for CM4)
echo "Compiling DSP plugin..."
${CROSS_PREFIX}gcc -Ofast -shared -fPIC \
    -std=gnu11 \
    -march=armv8-a -mtune=cortex-a72 \
    -fomit-frame-pointer -fno-stack-protector \
    -DNDEBUG \
    src/dsp/superboom.c \
    -o build/superboom.so \
    -Isrc/dsp \
    -lm

# Copy files to dist (use cat to avoid ExtFS deallocation issues with Docker)
echo "Packaging..."
cat src/module.json > dist/superboom/module.json
[ -f src/help.json ] && cat src/help.json > dist/superboom/help.json
[ -f src/ui_chain.js ] && cat src/ui_chain.js > dist/superboom/ui_chain.js
cat build/superboom.so > dist/superboom/superboom.so
chmod +x dist/superboom/superboom.so

# Create tarball for release
cd dist
tar -czvf super-boom-module.tar.gz superboom/
cd ..

echo ""
echo "=== Build Complete ==="
echo "Output: dist/superboom/"
echo "Tarball: dist/super-boom-module.tar.gz"
echo ""
echo "To install on Move:"
echo "  ./scripts/install.sh"
