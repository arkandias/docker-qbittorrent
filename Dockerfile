# syntax=docker/dockerfile:1

# create an up-to-date base image for everything
FROM alpine:3.20 AS base

RUN \
  apk --no-cache --update-cache upgrade

# run-time dependencies
RUN \
  apk --no-cache add \
    7zip \
    bash \
    curl \
    doas \
    python3 \
    qt6-qtbase \
    qt6-qtbase-sqlite \
    tini \
    tzdata

# image for building
FROM base AS builder

ARG QBT_VERSION
ARG LIBBT_VERSION
ARG LIBBT_CMAKE_FLAGS=""

# check environment variables
RUN \
  if [ -z "${QBT_VERSION}" ]; then \
    echo 'Missing QBT_VERSION variable. Check your command line arguments.' && \
    exit 1 ; \
  fi && \
  if [ -z "${LIBBT_VERSION}" ]; then \
    echo 'Missing LIBBT_VERSION variable. Check your command line arguments.' && \
    exit 1 ; \
  fi

# alpine linux packages:
# https://git.alpinelinux.org/aports/tree/community/libtorrent-rasterbar/APKBUILD
# https://git.alpinelinux.org/aports/tree/community/qbittorrent/APKBUILD
RUN \
  apk add \
    boost-dev \
    cmake \
    git \
    g++ \
    ninja \
    openssl-dev \
    patch \
    qt6-qtbase-dev \
    qt6-qttools-dev

# copy the patch file
COPY patch/tracker_request.patch /tmp/

# compiler, linker options:
# https://gcc.gnu.org/onlinedocs/gcc/Option-Summary.html
# https://gcc.gnu.org/onlinedocs/gcc/Link-Options.html
# https://sourceware.org/binutils/docs/ld/Options.html
ENV CFLAGS="-pipe -fstack-clash-protection -fstack-protector-strong -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS" \
    CXXFLAGS="-pipe -fstack-clash-protection -fstack-protector-strong -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS" \
    LDFLAGS="-gz -Wl,-O1,--as-needed,--sort-common,-z,now,-z,pack-relative-relocs,-z,relro"

# build libtorrent
RUN \
  git clone \
    --branch "${LIBBT_VERSION}" \
    --depth 1 \
    --recurse-submodules \
    https://github.com/arvidn/libtorrent.git && \
  cd libtorrent && \
  patch src/torrent.cpp < /tmp/tracker_request.patch && \
  cmake \
    -B build \
    -G Ninja \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_CXX_STANDARD=20 \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -Ddeprecated-functions=OFF \
    $LIBBT_CMAKE_FLAGS && \
  cmake --build build -j $(nproc) && \
  cmake --install build

# build qbittorrent
RUN \
  if [ "${QBT_VERSION}" = "devel" ]; then \
    git clone \
      --depth 1 \
      --recurse-submodules \
      https://github.com/qbittorrent/qBittorrent.git && \
    cd qBittorrent ; \
  else \
    wget "https://github.com/qbittorrent/qBittorrent/archive/refs/tags/release-${QBT_VERSION}.tar.gz" && \
    tar -xf "release-${QBT_VERSION}.tar.gz" && \
    cd "qBittorrent-release-${QBT_VERSION}" ; \
  fi && \
  cmake \
    -B build \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -DGUI=OFF && \
  cmake --build build -j $(nproc) && \
  cmake --install build

RUN \
  ldd /usr/bin/qbittorrent-nox | sort -f

# record compile-time Software Bill of Materials (sbom)
RUN \
  printf "Software Bill of Materials for building qbittorrent-nox\n\n" >> /sbom.txt && \
  cd libtorrent && \
  echo "libtorrent-rasterbar git $(git rev-parse HEAD)" >> /sbom.txt && \
  cd .. && \
  if [ "${QBT_VERSION}" = "devel" ]; then \
    cd qBittorrent && \
    echo "qBittorrent git $(git rev-parse HEAD)" >> /sbom.txt && \
    cd .. ; \
  else \
    echo "qBittorrent ${QBT_VERSION}" >> /sbom.txt ; \
  fi && \
  echo >> /sbom.txt && \
  apk list -I | sort >> /sbom.txt && \
  cat /sbom.txt

# image for running
FROM base

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL \
  build_version="Build version: ${VERSION}; Build date: ${BUILD_DATE}" \
  maintainer="Julien Hauseux <julien.hauseux@gmail.com>" \
  org.opencontainers.image.title="qBittorrent" \
  org.opencontainers.image.description="A Zero-Stats qBittorrent Container." \
  org.opencontainers.image.version="${VERSION}" \
  org.opencontainers.image.authors="Julien Hauseux <julien.hauseux@gmail.com>" \
  org.opencontainers.image.vendor="Julien Hauseux" \
  org.opencontainers.image.licenses="GPL-3.0-or-later" \
  org.opencontainers.image.base.name="alpine:3.20" \
  org.opencontainers.image.base.digest="" \
  org.opencontainers.image.created="${BUILD_DATE}" \
  org.opencontainers.image.revision="${VCS_REF}" \
  org.opencontainers.image.ref.name="${VCS_REF}" \
  org.opencontainers.image.url="https://github.com/arkandias/docker-qbittorrent" \
  org.opencontainers.image.source="https://github.com/arkandias/docker-qbittorrent" \
  org.opencontainers.image.documentation="https://github.com/arkandias/docker-qbittorrent/README.md"

RUN \
  adduser \
    -D \
    -H \
    -s /sbin/nologin \
    -u 1000 \
    qbtUser && \
  echo "permit nopass :root" >> "/etc/doas.d/doas.conf"

COPY --from=builder /usr/bin/qbittorrent-nox /usr/bin/qbittorrent-nox

COPY --from=builder /sbom.txt /sbom.txt

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/sbin/tini", "-g", "--", "/entrypoint.sh"]
