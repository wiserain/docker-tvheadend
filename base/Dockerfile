############## base image ##############
FROM ghcr.io/linuxserver/baseimage-ubuntu:noble AS base
FROM base AS builder

ARG DEBIAN_FRONTEND="noninteractive"
ARG APT_MIRROR="archive.ubuntu.com"

RUN \
    echo "**** apt source change for local dev ****" && \
    sed -i "s/archive.ubuntu.com/$APT_MIRROR/g" /etc/apt/sources.list && \
    echo "**** install basic build tools ****" && \
    apt-get update -yq && \
    apt-get install -yq --no-install-recommends \
        autoconf \
        automake \
        build-essential \
        git \
        jq \
        libtool \
        pkg-config \
        wget

############## tvheadend ##############
FROM builder AS tvheadend

ARG MAKEFLAGS="-j2"
ARG DEBIAN_FRONTEND="noninteractive"
ARG TARGETARCH
ARG TVHEADEND_COMMIT

RUN \
    echo "**** tvheadend source ****" && \
    if [ -z ${TVHEADEND_COMMIT+x} ]; then \
        git clone https://github.com/tvheadend/tvheadend.git /tmp/tvheadend -b master; \
    else \
        git clone https://github.com/tvheadend/tvheadend.git /tmp/tvheadend && \
        git -C /tmp/tvheadend checkout ${TVHEADEND_COMMIT}; \
    fi

RUN \
    echo "**** install build-deps ****" && \
    apt-get install -yq --no-install-recommends \
        ca-certificates \
        cmake \
        gettext \
        libavahi-client-dev \
        libdvbcsa-dev \
        libhdhomerun-dev \
        libpcre2-dev \
        libpcre3-dev \
        # libperl-dev \
        libssl-dev \
        liburiparser-dev \
        libva-dev \
        # libx11-dev \
        markdown \
        pngquant \
        python3-requests \
        python3-setuptools \
        $([ "$TARGETARCH" != "amd64" ] && echo "libavcodec-dev libavfilter-dev libavformat-dev libavutil-dev libopus-dev libswresample-dev libswscale-dev libvpx-dev libx264-dev libx265-dev") \
        zlib1g-dev && \
    echo "**** setting default /usr/bin/python ****" && \
    if [ ! -e /usr/bin/python ]; then ln -sf /usr/bin/python3 /usr/bin/python; fi

WORKDIR /tmp/tvheadend
RUN \
    echo "**** compile tvheadend ****" && \
    if [ "$TARGETARCH" = "amd64" ]; then \
        TVH_CONFIGURE_ARCH="\
            --enable-ffmpeg_static \
            --enable-libopus --enable-libopus_static \
            --enable-libvorbis --enable-libvorbis_static \
            --enable-libvpx --enable-libvpx_static \
            --enable-libx264 --enable-libx264_static \
            --enable-libx265 --enable-libx265_static \
            --enable-libfdkaac --enable-libfdkaac_static \
            --enable-libtheora --enable-libtheora_static"; \
    else \
        TVH_CONFIGURE_ARCH="\
            --arch=arm64 \
            --disable-ffmpeg_static \
            --disable-libopus_static \
            --disable-libvorbis_static \
            --disable-libvpx_static \
            --disable-libx264_static \
            --disable-libx265_static \
            --disable-libfdkaac_static \
            --disable-libtheora_static"; \
    fi && \
    ./configure \
        ${TVH_CONFIGURE_ARCH} \
        `#Options` \
        --disable-bintray_cache \
        --enable-dvbcsa \
        --enable-hdhomerun_static \
        --enable-hdhomerun_client \
        --enable-libav \
        --enable-pngquant \
        --enable-trace \
        --enable-vaapi \
        --infodir=/usr/share/info \
        --localstatedir=/var \
        --mandir=/usr/share/man \
        --prefix=/usr \
        --python=python3 \
        --sysconfdir=/config && \
    make && \
    make DESTDIR=/tvheadend install

############## libdvbcsa ##############
FROM builder AS libdvbcsa

ARG TARGETARCH

# copy patches
COPY patches/libdvbcsa.patch /tmp/patches/

RUN \
    echo "**** libdvbcsa source ****" && \
    git clone https://github.com/glenvt18/libdvbcsa.git /tmp/libdvbcsa && \
    cd /tmp/libdvbcsa && \
    git checkout 2a1e61e569a621c55c2426f235f42c2398b7f18f && \
    echo "**** patch libdvbcsa with icam support****" && \
    git config apply.whitespace nowarn && \
    git apply /tmp/patches/libdvbcsa.patch && \
    sed 's# == 4)# > 0)#' -i src/dvbcsa_pv.h

WORKDIR /tmp/libdvbcsa
RUN \
    echo "**** compile libdvbcsa ****" && \
    ./bootstrap && \
    ./configure \
        $([ "$TARGETARCH" = "amd64" ] && echo "--enable-ssse3") \
        --with-pic \
        --prefix=/usr \
        --sysconfdir=/etc \
        --mandir=/usr/share/man \
        --infodir=/usr/share/info \
        --localstatedir=/var && \
    make -j$(nproc) && \
    make check && \
    make DESTDIR=/libdvbcsa install

############## collect stage ##############
FROM base AS collector

COPY --from=tvheadend /tvheadend/usr/ /bar/usr/
COPY --from=libdvbcsa /libdvbcsa/usr/ /bar/usr/

# COPY --from=ghcr.io/linuxserver/picons-builder /picons.tar.bz2 /picons.tar.bz2
# RUN mkdir -p /bar/picons && tar xf /picons.tar.bz2 -C /bar/picons
RUN mkdir -p /bar/picons

COPY root/ /bar/

############## release tvhbase ##############
FROM base

ARG DEBIAN_FRONTEND="noninteractive"
ARG TARGETARCH

# environment settings
ARG TZ="Asia/Seoul"
ENV HOME="/config"

RUN \
    echo "**** install runtime packages ****" && \
    apt-get update && \
    apt-get install -yq  --no-install-recommends \
        comskip \
        ffmpeg \
        `# tvheadend` \
        bzip2 \
        curl \
        gzip \
        libavahi-common3 \
        libavahi-client3 \
        libpcre2-8-0 \
        liburiparser1 \
        libva-drm2 \
        libva2 \
        mesa-va-drivers \
        mesa-vdpau-drivers \
        python3-requests \
        vainfo \
        wget \
        $([ "$TARGETARCH" = "amd64" ] && echo "intel-media-va-driver i965-va-driver libdrm-intel1") \
        xmltv-util && \
    echo "**** setting default /usr/bin/python ****" && \
    if [ ! -e /usr/bin/python ]; then ln -sf /usr/bin/python3 /usr/bin/python; fi && \
    echo "**** cleanup ****" && \
    apt-get autoremove -y && \
    rm -rf \
        /tmp/* \
        /var/tmp/* \
        /var/cache/* \
        /var/lib/apt/lists/*

# copy local files and buildstage artifacts
COPY --from=collector /bar/ /

# ports and volumes
EXPOSE 9981 9982
VOLUME /config
