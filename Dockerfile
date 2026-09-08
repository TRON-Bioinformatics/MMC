# syntax=docker/dockerfile:1

# =============================================================================
# MMC (MiniMizer Counter) - minimal multi-stage build
#
# Builds the mmc, mmc_dump and mmc_tools binaries exactly as described in the
# README (a plain `make`), then ships them in a minimal runtime image.
#
# The Linux Makefile links everything statically (-static) against the vendored
# zlib/bzip2 archives in kmc_core/libs and kmc_tools/libs, so the resulting
# binaries have NO runtime dynamic dependencies and run on a bare
# debian:bookworm-slim (or even scratch).
#
# Base image: debian:bookworm-slim (chosen over Alpine because the vendored
# static archives are glibc / x86-64 builds; Alpine's musl toolchain would
# require rebuilding zlib/bzip2, which would deviate from the README build).
#
# ARCHITECTURE: amd64 (x86-64) ONLY - the Makefile uses -m64 / -msse2 /
# -msse4.1 / -mavx / -mavx2, which do not exist on other architectures.
# =============================================================================

ARG DEBIAN_VERSION=bookworm-slim

# -----------------------------------------------------------------------------
# Stage 1: build
# -----------------------------------------------------------------------------
FROM debian:${DEBIAN_VERSION} AS builder

# Fail fast on unsupported architectures, before doing any work.
ARG TARGETARCH=amd64
RUN test "$TARGETARCH" = "amd64" \
    || { echo "ERROR: MMC only builds on amd64 (x86-64 SIMD flags in the Makefile); got '$TARGETARCH'." >&2; exit 1; }

# build-essential = gcc, g++, libc6-dev (libc.a/libm.a), binutils (ar), make
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /mmc

# Copy the source tree (.dockerignore keeps the context small).
COPY . .

# Build all three binaries (the `all` target: mmc, mmc_dump, mmc_tools).
# `make clean` first so no stale artifacts can interfere.
RUN make clean \
    && make -j"$(nproc)"

# -----------------------------------------------------------------------------
# Stage 2: minimal runtime
# -----------------------------------------------------------------------------
FROM debian:${DEBIAN_VERSION} AS runtime

# The binaries are fully static, so nothing else is required at runtime.
COPY --from=builder /mmc/bin/mmc       /usr/local/bin/mmc
COPY --from=builder /mmc/bin/mmc_dump  /usr/local/bin/mmc_dump
COPY --from=builder /mmc/bin/mmc_tools /usr/local/bin/mmc_tools

# Default to printing mmc's usage. Override with e.g.:
#   docker run --rm -it -v "$PWD/data:/data" mmc mmc -fq /data/reads.fq.gz /data/out /data/work
CMD ["mmc"]
