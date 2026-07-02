############## base image with libva driver ##############
# https://gist.github.com/Brainiarc7/eb45d2e22afec7534f4a117d15fe6d89
FROM ghcr.io/linuxserver/baseimage-ubuntu:noble AS base

ARG MAKEFLAGS="-j2"
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
        libtool \
        pkg-config \
        wget && \
    echo "**** compile libva ****" && \
    apt-get install -yq --no-install-recommends \
        curl \
        valgrind \
        libdrm-dev \
        libx11-dev \
        xorg-dev && \
    git clone https://github.com/intel/libva /tmp/libva \
        -b $(curl -sX GET "https://api.github.com/repos/intel/libva/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]') && \
    cd /tmp/libva && \
    ./autogen.sh && \
    ./configure && \
    make VERBOSE=1 && \
    make install && \
    ldconfig && \
    echo "**** compile intel-vaapi-driver ****" && \
    git clone https://github.com/intel/intel-vaapi-driver /tmp/intel-vaapi-driver \
        -b $(curl -sX GET "https://api.github.com/repos/intel/intel-vaapi-driver/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]') && \
    cd /tmp/intel-vaapi-driver && \
    ./autogen.sh && \
    ./configure --enable-hybrid-codec && \
    make VERBOSE=1 && \
    make install && \
    echo "**** compile libva-utils ****" && \
    git clone https://github.com/intel/libva-utils /tmp/libva-utils \
        -b $(curl -sX GET "https://api.github.com/repos/intel/libva-utils/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]') && \
    cd /tmp/libva-utils && \
    ./autogen.sh && \
    ./configure && \
    make VERBOSE=1 && \
    make install && \
    echo "**** cleanup and install runtime packages ****" && \
    apt-get purge -y \
        `#Basic` \
        autoconf \
        automake \
        build-essential \
        git \
        libtool \
        pkg-config \
        wget \
        \
        `#libva` \
        curl \
        libdrm-dev \
        libx11-dev \
        xorg-dev && \
    apt-get install -yq --no-install-recommends \
        libx11-6 \
        libxext6 \
        libxfixes3 \
        libdrm-intel1 && \
    apt-get autoremove -y && \
    rm -rf \
        /tmp/* \
        /var/tmp/* \
        /var/cache/* \
        /var/lib/apt/lists/*

############## tvheadend ##############
FROM base AS tvheadend

ARG MAKEFLAGS="-j2"
ARG DEBIAN_FRONTEND="noninteractive"
ARG TVHEADEND_COMMIT

RUN \
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
        # libx11-dev \
        markdown \
        pngquant \
        python3-requests \
        python3-setuptools \
        zlib1g-dev \
        \
        `#Codec` \
        libx264-dev \
        libx265-dev \
        libvpx-dev \
        # libfdk-aac-dev \
        # libogg-dev \
        libopus-dev \
        # libvorbis-dev \
        libavcodec-dev \
        libavfilter-dev \
        libavformat-dev \
        libavutil-dev \
        libswresample-dev \
        libswscale-dev && \
    echo "**** setting default /usr/bin/python ****" && \
    if [ ! -e /usr/bin/python ]; then ln -sf /usr/bin/python3 /usr/bin/python; fi

WORKDIR /tmp/tvheadend
RUN \
    echo "**** compile tvheadend ****" && \
    ./configure \
        `#Encoding` \
        --enable-libffmpeg_static \
        --enable-libopus \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libfdkaac \
        \
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
FROM base AS libdvbcsa

RUN \
    echo "**** install build packages ****" && \
    apt-get update -yq && \
    apt-get install -yq --no-install-recommends \
        autoconf \
        automake \
        build-essential \
        git \
        libtool

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
        --enable-ssse3 \
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

# environment settings
ARG TZ="Asia/Seoul"
ENV HOME="/config"

RUN \
    echo "**** install runtime packages ****" && \
    apt-get update && \
    apt-get install -yq  --no-install-recommends \
        `# ffmpeg` \
        ca-certificates \
        comskip \
        expat \
        ffmpeg \
        libgomp1 \
        `# tvheadend` \
        bzip2 \
        curl \
        gzip \
        libavahi-common3 \
        libavahi-client3 \
        libpcre2-8-0 \
        liburiparser1 \
        mesa-va-drivers \
        mesa-vdpau-drivers \
        python3-requests \
        wget \
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
