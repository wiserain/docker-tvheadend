############## base image with libva driver ##############
# https://gist.github.com/Brainiarc7/eb45d2e22afec7534f4a117d15fe6d89
FROM ghcr.io/linuxserver/baseimage-ubuntu:focal as base

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
  echo "**** the latest development headers for libva ****" && \
  apt-get install -yq \
    software-properties-common && \
  add-apt-repository ppa:oibaf/graphics-drivers && \
  apt-get update -yq && \
  apt-get upgrade -yq && \
  apt-get dist-upgrade -yq && \
  echo "**** compile libva ****" && \
  apt-get install -yq --no-install-recommends \
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
  # apg-get -yq --no-install-recommends libcrmt-dev libcrmt1
  echo "**** compile cmrt ****" && \
  git clone https://github.com/intel/cmrt /tmp/cmrt \
    -b $(curl -sX GET "https://api.github.com/repos/intel/cmrt/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]') && \
  cd /tmp/cmrt && \
  ./autogen.sh && \
  ./configure && \
  make VERBOSE=1 && \
  make install && \
  echo "**** compile intel-hybrid-driver ****" && \
  git clone https://github.com/intel/intel-hybrid-driver /tmp/intel-hybrid-driver \
    -b $(curl -sX GET "https://api.github.com/repos/intel/intel-hybrid-driver/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]') && \
  cd /tmp/intel-hybrid-driver && \
  ./autogen.sh && \
  ./configure && \
  make VERBOSE=1 && \
  make install && \
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
    `#headers` \
    software-properties-common \
    \
    `#libva` \
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

############## build ffmpeg ##############
# https://github.com/jrottenberg/ffmpeg/blob/main/docker-images/4.4/vaapi2004/Dockerfile
FROM base as ffmpeg

ENV         FFMPEG_VERSION=4.4.3 \
    AOM_VERSION=v1.0.0 \
    CHROMAPRINT_VERSION=1.5.0 \
    FDKAAC_VERSION=0.1.5 \
    FONTCONFIG_VERSION=2.12.4 \
    FREETYPE_VERSION=2.10.4 \
    FRIBIDI_VERSION=0.19.7 \
    KVAZAAR_VERSION=2.0.0 \
    LAME_VERSION=3.100 \
    LIBASS_VERSION=0.13.7 \
    LIBPTHREAD_STUBS_VERSION=0.4 \
    LIBVIDSTAB_VERSION=1.1.0 \
    LIBXCB_VERSION=1.13.1 \
    XCBPROTO_VERSION=1.13 \
    OGG_VERSION=1.3.2 \
    OPENCOREAMR_VERSION=0.1.5 \
    OPUS_VERSION=1.2 \
    OPENJPEG_VERSION=2.1.2 \
    THEORA_VERSION=1.1.1 \
    VORBIS_VERSION=1.3.5 \
    VPX_VERSION=1.8.0 \
    WEBP_VERSION=1.0.2 \
    X264_VERSION=20170226-2245-stable \
    X265_VERSION=3.4 \
    XAU_VERSION=1.0.9 \
    XORG_MACROS_VERSION=1.19.2 \
    XPROTO_VERSION=7.0.31 \
    XVID_VERSION=1.3.4 \
    LIBXML2_VERSION=2.9.12 \
    LIBBLURAY_VERSION=1.1.2 \
    LIBZMQ_VERSION=4.3.2 \
    LIBSRT_VERSION=1.4.1 \
    LIBARIBB24_VERSION=1.0.3 \
    LIBPNG_VERSION=1.6.9 \
    LIBVMAF_VERSION=2.1.1 \
    SRC=/usr/local

ARG         FREETYPE_SHA256SUM="5eab795ebb23ac77001cfb68b7d4d50b5d6c7469247b0b01b2c953269f658dac freetype-2.10.4.tar.gz"
ARG         FRIBIDI_SHA256SUM="3fc96fa9473bd31dcb5500bdf1aa78b337ba13eb8c301e7c28923fea982453a8 0.19.7.tar.gz"
ARG         LIBASS_SHA256SUM="8fadf294bf701300d4605e6f1d92929304187fca4b8d8a47889315526adbafd7 0.13.7.tar.gz"
ARG         LIBVIDSTAB_SHA256SUM="14d2a053e56edad4f397be0cb3ef8eb1ec3150404ce99a426c4eb641861dc0bb v1.1.0.tar.gz"
ARG         OGG_SHA256SUM="e19ee34711d7af328cb26287f4137e70630e7261b17cbe3cd41011d73a654692 libogg-1.3.2.tar.gz"
ARG         OPUS_SHA256SUM="77db45a87b51578fbc49555ef1b10926179861d854eb2613207dc79d9ec0a9a9 opus-1.2.tar.gz"
ARG         THEORA_SHA256SUM="40952956c47811928d1e7922cda3bc1f427eb75680c3c37249c91e949054916b libtheora-1.1.1.tar.gz"
ARG         VORBIS_SHA256SUM="6efbcecdd3e5dfbf090341b485da9d176eb250d893e3eb378c428a2db38301ce libvorbis-1.3.5.tar.gz"
ARG         XVID_SHA256SUM="4e9fd62728885855bc5007fe1be58df42e5e274497591fec37249e1052ae316f xvidcore-1.3.4.tar.gz"
ARG         LIBBLURAY_SHA256SUM="a3dd452239b100dc9da0d01b30e1692693e2a332a7d29917bf84bb10ea7c0b42 libbluray-1.1.2.tar.bz2"
ARG         LIBZMQ_SHA256SUM="02ecc88466ae38cf2c8d79f09cfd2675ba299a439680b64ade733e26a349edeb v4.3.2.tar.gz"
ARG         LIBARIBB24_SHA256SUM="f61560738926e57f9173510389634d8c06cabedfa857db4b28fb7704707ff128 v1.0.3.tar.gz"


ARG         LD_LIBRARY_PATH=/opt/ffmpeg/lib
ARG         MAKEFLAGS="-j2"
ARG         PKG_CONFIG_PATH="/opt/ffmpeg/share/pkgconfig:/opt/ffmpeg/lib/pkgconfig:/opt/ffmpeg/lib64/pkgconfig"
ARG         PREFIX=/opt/ffmpeg
ARG         LD_LIBRARY_PATH="/opt/ffmpeg/lib:/opt/ffmpeg/lib64"


ARG DEBIAN_FRONTEND=noninteractive

RUN      buildDeps="autoconf \
                    automake \
                    cmake \
                    curl \
                    bzip2 \
                    libexpat1-dev \
                    g++ \
                    gcc \
                    git \
                    gperf \
                    libtool \
                    make \
                    meson \
                    nasm \
                    perl \
                    pkg-config \
                    python \
                    libssl-dev \
                    yasm \
                    libva-dev \
                    zlib1g-dev" && \
        apt-get -yqq update && \
        apt-get install -yq --no-install-recommends ${buildDeps}
## libvmaf https://github.com/Netflix/vmaf
RUN \
        if which meson || false; then \
        echo "Building VMAF." && \
        DIR=/tmp/vmaf && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://github.com/Netflix/vmaf/archive/v${LIBVMAF_VERSION}.tar.gz && \
        tar -xz --strip-components=1 -f v${LIBVMAF_VERSION}.tar.gz && \
        cd /tmp/vmaf/libvmaf && \
        meson build --buildtype release --prefix=${PREFIX} && \
        ninja -vC build && \
        ninja -vC build install && \
        mkdir -p ${PREFIX}/share/model/ && \
        cp -r /tmp/vmaf/model/* ${PREFIX}/share/model/ && \
        rm -rf ${DIR}; \
        else \
        echo "VMAF skipped."; \
        fi

## opencore-amr https://sourceforge.net/projects/opencore-amr/
RUN \
        DIR=/tmp/opencore-amr && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sL https://sourceforge.net/projects/opencore-amr/files/opencore-amr/opencore-amr-${OPENCOREAMR_VERSION}.tar.gz/download | \
        tar -zx --strip-components=1 && \
        ./configure --prefix="${PREFIX}" --enable-shared  && \
        make && \
        make install && \
        rm -rf ${DIR}
## x264 http://www.videolan.org/developers/x264.html
RUN \
        DIR=/tmp/x264 && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sL https://download.videolan.org/pub/videolan/x264/snapshots/x264-snapshot-${X264_VERSION}.tar.bz2 | \
        tar -jx --strip-components=1 && \
        ./configure --prefix="${PREFIX}" --enable-shared --enable-pic --disable-cli && \
        make && \
        make install && \
        rm -rf ${DIR}
### x265 http://x265.org/
RUN \
        DIR=/tmp/x265 && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sL https://github.com/videolan/x265/archive/refs/tags/${X265_VERSION}.tar.gz | \
        tar -zx && \
        cd x265-${X265_VERSION}/build/linux && \
        sed -i "/-DEXTRA_LIB/ s/$/ -DCMAKE_INSTALL_PREFIX=\${PREFIX}/" multilib.sh && \
        sed -i "/^cmake/ s/$/ -DENABLE_CLI=OFF/" multilib.sh && \
        ./multilib.sh && \
        make -C 8bit install && \
        rm -rf ${DIR}
### libogg https://www.xiph.org/ogg/
RUN \
        DIR=/tmp/ogg && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO http://downloads.xiph.org/releases/ogg/libogg-${OGG_VERSION}.tar.gz && \
        echo ${OGG_SHA256SUM} | sha256sum --check && \
        tar -zx --strip-components=1 -f libogg-${OGG_VERSION}.tar.gz && \
        ./configure --prefix="${PREFIX}" --enable-shared  && \
        make && \
        make install && \
        rm -rf ${DIR}
### libopus https://www.opus-codec.org/
RUN \
        DIR=/tmp/opus && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://archive.mozilla.org/pub/opus/opus-${OPUS_VERSION}.tar.gz && \
        echo ${OPUS_SHA256SUM} | sha256sum --check && \
        tar -zx --strip-components=1 -f opus-${OPUS_VERSION}.tar.gz && \
        autoreconf -fiv && \
        ./configure --prefix="${PREFIX}" --enable-shared && \
        make && \
        make install && \
        rm -rf ${DIR}
### libvorbis https://xiph.org/vorbis/
RUN \
        DIR=/tmp/vorbis && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO http://downloads.xiph.org/releases/vorbis/libvorbis-${VORBIS_VERSION}.tar.gz && \
        echo ${VORBIS_SHA256SUM} | sha256sum --check && \
        tar -zx --strip-components=1 -f libvorbis-${VORBIS_VERSION}.tar.gz && \
        ./configure --prefix="${PREFIX}" --with-ogg="${PREFIX}" --enable-shared && \
        make && \
        make install && \
        rm -rf ${DIR}
### libtheora http://www.theora.org/
RUN \
        DIR=/tmp/theora && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO http://downloads.xiph.org/releases/theora/libtheora-${THEORA_VERSION}.tar.gz && \
        echo ${THEORA_SHA256SUM} | sha256sum --check && \
        tar -zx --strip-components=1 -f libtheora-${THEORA_VERSION}.tar.gz && \
        ./configure --prefix="${PREFIX}" --with-ogg="${PREFIX}" --enable-shared && \
        make && \
        make install && \
        rm -rf ${DIR}
### libvpx https://www.webmproject.org/code/
RUN \
        DIR=/tmp/vpx && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sL https://codeload.github.com/webmproject/libvpx/tar.gz/v${VPX_VERSION} | \
        tar -zx --strip-components=1 && \
        ./configure --prefix="${PREFIX}" --enable-vp8 --enable-vp9 --enable-vp9-highbitdepth --enable-pic --enable-shared \
        --disable-debug --disable-examples --disable-docs --disable-install-bins  && \
        make && \
        make install && \
        rm -rf ${DIR}
### libwebp https://developers.google.com/speed/webp/
RUN \
        DIR=/tmp/vebp && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sL https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${WEBP_VERSION}.tar.gz | \
        tar -zx --strip-components=1 && \
        ./configure --prefix="${PREFIX}" --enable-shared  && \
        make && \
        make install && \
        rm -rf ${DIR}
### libmp3lame http://lame.sourceforge.net/
RUN \
        DIR=/tmp/lame && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sL https://sourceforge.net/projects/lame/files/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz/download | \
        tar -zx --strip-components=1 && \
        ./configure --prefix="${PREFIX}" --bindir="${PREFIX}/bin" --enable-shared --enable-nasm --disable-frontend && \
        make && \
        make install && \
        rm -rf ${DIR}
### xvid https://www.xvid.com/
RUN \
        DIR=/tmp/xvid && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO http://downloads.xvid.org/downloads/xvidcore-${XVID_VERSION}.tar.gz && \
        echo ${XVID_SHA256SUM} | sha256sum --check && \
        tar -zx -f xvidcore-${XVID_VERSION}.tar.gz && \
        cd xvidcore/build/generic && \
        ./configure --prefix="${PREFIX}" --bindir="${PREFIX}/bin" && \
        make && \
        make install && \
        rm -rf ${DIR}
### fdk-aac https://github.com/mstorsjo/fdk-aac
RUN \
        DIR=/tmp/fdk-aac && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sL https://github.com/mstorsjo/fdk-aac/archive/v${FDKAAC_VERSION}.tar.gz | \
        tar -zx --strip-components=1 && \
        autoreconf -fiv && \
        ./configure --prefix="${PREFIX}" --enable-shared --datadir="${DIR}" && \
        make && \
        make install && \
        rm -rf ${DIR}
## openjpeg https://github.com/uclouvain/openjpeg
RUN \
        DIR=/tmp/openjpeg && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sL https://github.com/uclouvain/openjpeg/archive/v${OPENJPEG_VERSION}.tar.gz | \
        tar -zx --strip-components=1 && \
        cmake -DBUILD_THIRDPARTY:BOOL=ON -DCMAKE_INSTALL_PREFIX="${PREFIX}" . && \
        make && \
        make install && \
        rm -rf ${DIR}
## freetype https://www.freetype.org/
RUN  \
        DIR=/tmp/freetype && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VERSION}.tar.gz && \
        echo ${FREETYPE_SHA256SUM} | sha256sum --check && \
        tar -zx --strip-components=1 -f freetype-${FREETYPE_VERSION}.tar.gz && \
        ./configure --prefix="${PREFIX}" --disable-static --enable-shared && \
        make && \
        make install && \
        rm -rf ${DIR}
## libvstab https://github.com/georgmartius/vid.stab
RUN  \
        DIR=/tmp/vid.stab && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://github.com/georgmartius/vid.stab/archive/v${LIBVIDSTAB_VERSION}.tar.gz && \
        echo ${LIBVIDSTAB_SHA256SUM} | sha256sum --check &&  \
        tar -zx --strip-components=1 -f v${LIBVIDSTAB_VERSION}.tar.gz && \
        cmake -DCMAKE_INSTALL_PREFIX="${PREFIX}" . && \
        make && \
        make install && \
        rm -rf ${DIR}
## fridibi https://www.fribidi.org/
RUN  \
        DIR=/tmp/fribidi && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://github.com/fribidi/fribidi/archive/${FRIBIDI_VERSION}.tar.gz && \
        echo ${FRIBIDI_SHA256SUM} | sha256sum --check && \
        tar -zx --strip-components=1 -f ${FRIBIDI_VERSION}.tar.gz && \
        sed -i 's/^SUBDIRS =.*/SUBDIRS=gen.tab charset lib bin/' Makefile.am && \
        ./bootstrap --no-config --auto && \
        ./configure --prefix="${PREFIX}" --disable-static --enable-shared && \
        make -j1 && \
        make install && \
        rm -rf ${DIR}
## fontconfig https://www.freedesktop.org/wiki/Software/fontconfig/
RUN  \
        DIR=/tmp/fontconfig && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://www.freedesktop.org/software/fontconfig/release/fontconfig-${FONTCONFIG_VERSION}.tar.bz2 && \
        tar -jx --strip-components=1 -f fontconfig-${FONTCONFIG_VERSION}.tar.bz2 && \
        ./configure --prefix="${PREFIX}" --disable-static --enable-shared && \
        make && \
        make install && \
        rm -rf ${DIR}
## libass https://github.com/libass/libass
RUN  \
        DIR=/tmp/libass && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://github.com/libass/libass/archive/${LIBASS_VERSION}.tar.gz && \
        echo ${LIBASS_SHA256SUM} | sha256sum --check && \
        tar -zx --strip-components=1 -f ${LIBASS_VERSION}.tar.gz && \
        ./autogen.sh && \
        ./configure --prefix="${PREFIX}" --disable-static --enable-shared && \
        make && \
        make install && \
        rm -rf ${DIR}
## kvazaar https://github.com/ultravideo/kvazaar
RUN \
        DIR=/tmp/kvazaar && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://github.com/ultravideo/kvazaar/archive/v${KVAZAAR_VERSION}.tar.gz && \
        tar -zx --strip-components=1 -f v${KVAZAAR_VERSION}.tar.gz && \
        ./autogen.sh && \
        ./configure --prefix="${PREFIX}" --disable-static --enable-shared && \
        make && \
        make install && \
        rm -rf ${DIR}

RUN \
        DIR=/tmp/aom && \
        git clone --branch ${AOM_VERSION} --depth 1 https://aomedia.googlesource.com/aom ${DIR} ; \
        cd ${DIR} ; \
        rm -rf CMakeCache.txt CMakeFiles ; \
        mkdir -p ./aom_build ; \
        cd ./aom_build ; \
        cmake -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DBUILD_SHARED_LIBS=1 ..; \
        make ; \
        make install ; \
        rm -rf ${DIR}

## libxcb (and supporting libraries) for screen capture https://xcb.freedesktop.org/
RUN \
        DIR=/tmp/xorg-macros && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://www.x.org/archive//individual/util/util-macros-${XORG_MACROS_VERSION}.tar.gz && \
        tar -zx --strip-components=1 -f util-macros-${XORG_MACROS_VERSION}.tar.gz && \
        ./configure --srcdir=${DIR} --prefix="${PREFIX}" && \
        make && \
        make install && \
        rm -rf ${DIR}

RUN \
        DIR=/tmp/xproto && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://www.x.org/archive/individual/proto/xproto-${XPROTO_VERSION}.tar.gz && \
        tar -zx --strip-components=1 -f xproto-${XPROTO_VERSION}.tar.gz && \
        ./configure --srcdir=${DIR} --prefix="${PREFIX}" && \
        make && \
        make install && \
        rm -rf ${DIR}

RUN \
        DIR=/tmp/libXau && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://www.x.org/archive/individual/lib/libXau-${XAU_VERSION}.tar.gz && \
        tar -zx --strip-components=1 -f libXau-${XAU_VERSION}.tar.gz && \
        ./configure --srcdir=${DIR} --prefix="${PREFIX}" && \
        make && \
        make install && \
        rm -rf ${DIR}

RUN \
        DIR=/tmp/libpthread-stubs && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://xcb.freedesktop.org/dist/libpthread-stubs-${LIBPTHREAD_STUBS_VERSION}.tar.gz && \
        tar -zx --strip-components=1 -f libpthread-stubs-${LIBPTHREAD_STUBS_VERSION}.tar.gz && \
        ./configure --prefix="${PREFIX}" && \
        make && \
        make install && \
        rm -rf ${DIR}

RUN \
        DIR=/tmp/libxcb-proto && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://xcb.freedesktop.org/dist/xcb-proto-${XCBPROTO_VERSION}.tar.gz && \
        tar -zx --strip-components=1 -f xcb-proto-${XCBPROTO_VERSION}.tar.gz && \
        ACLOCAL_PATH="${PREFIX}/share/aclocal" ./autogen.sh && \
        ./configure --prefix="${PREFIX}" && \
        make && \
        make install && \
        rm -rf ${DIR}

RUN \
        DIR=/tmp/libxcb && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://xcb.freedesktop.org/dist/libxcb-${LIBXCB_VERSION}.tar.gz && \
        tar -zx --strip-components=1 -f libxcb-${LIBXCB_VERSION}.tar.gz && \
        ACLOCAL_PATH="${PREFIX}/share/aclocal" ./autogen.sh && \
        ./configure --prefix="${PREFIX}" --disable-static --enable-shared && \
        make && \
        make install && \
        rm -rf ${DIR}

## libxml2 - for libbluray
RUN \
        DIR=/tmp/libxml2 && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sL https://github.com/GNOME/libxml2/archive/refs/tags/v${LIBXML2_VERSION}.tar.gz | \
        tar -xz --strip-components=1 && \
        ./autogen.sh --prefix="${PREFIX}" --with-ftp=no --with-http=no --with-python=no && \
        make && \
        make install && \
        rm -rf ${DIR}

## libbluray - Requires libxml, freetype, and fontconfig
RUN \
        DIR=/tmp/libbluray && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://download.videolan.org/pub/videolan/libbluray/${LIBBLURAY_VERSION}/libbluray-${LIBBLURAY_VERSION}.tar.bz2 && \
        echo ${LIBBLURAY_SHA256SUM} | sha256sum --check && \
        tar -jx --strip-components=1 -f libbluray-${LIBBLURAY_VERSION}.tar.bz2 && \
        ./configure --prefix="${PREFIX}" --disable-examples --disable-bdjava-jar --disable-static --enable-shared && \
        make && \
        make install && \
        rm -rf ${DIR}

## libzmq https://github.com/zeromq/libzmq/
RUN \
        DIR=/tmp/libzmq && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://github.com/zeromq/libzmq/archive/v${LIBZMQ_VERSION}.tar.gz && \
        echo ${LIBZMQ_SHA256SUM} | sha256sum --check && \
        tar -xz --strip-components=1 -f v${LIBZMQ_VERSION}.tar.gz && \
        ./autogen.sh && \
        ./configure --prefix="${PREFIX}" && \
        make && \
        make check && \
        make install && \
        rm -rf ${DIR}

## libsrt https://github.com/Haivision/srt
RUN \
        DIR=/tmp/srt && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://github.com/Haivision/srt/archive/v${LIBSRT_VERSION}.tar.gz && \
        tar -xz --strip-components=1 -f v${LIBSRT_VERSION}.tar.gz && \
        cmake -DCMAKE_INSTALL_PREFIX="${PREFIX}" . && \
        make && \
        make install && \
        rm -rf ${DIR}

## libpng
RUN \
        DIR=/tmp/png && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        git clone https://git.code.sf.net/p/libpng/code ${DIR} -b v${LIBPNG_VERSION} --depth 1 && \
        ./autogen.sh && \
        ./configure --prefix="${PREFIX}" && \
        make check && \
        make install && \
        rm -rf ${DIR}

## libaribb24
RUN \
        DIR=/tmp/b24 && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://github.com/nkoriyama/aribb24/archive/v${LIBARIBB24_VERSION}.tar.gz && \
        echo ${LIBARIBB24_SHA256SUM} | sha256sum --check && \
        tar -xz --strip-components=1 -f v${LIBARIBB24_VERSION}.tar.gz && \
        autoreconf -fiv && \
        ./configure CFLAGS="-I${PREFIX}/include -fPIC" --prefix="${PREFIX}" && \
        make && \
        make install && \
        rm -rf ${DIR}

## Download ffmpeg https://ffmpeg.org/
RUN  \
        DIR=/tmp/ffmpeg && mkdir -p ${DIR} && cd ${DIR} && \
        curl -sLO https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 && \
        tar -jx --strip-components=1 -f ffmpeg-${FFMPEG_VERSION}.tar.bz2 && \
        ./configure     --disable-debug  --disable-doc    --disable-ffplay   --enable-shared --enable-gpl  --extra-libs=-ldl && \
        make ;  make install





## Build ffmpeg https://ffmpeg.org/
RUN  \
        DIR=/tmp/ffmpeg && cd ${DIR} && \
        ./configure \
        --disable-debug \
        --disable-doc \
        --disable-ffplay \
        --enable-avresample \
        --enable-fontconfig \
        --enable-gpl \
        --enable-libaom \
        --enable-libaribb24 \
        --enable-libass \
        --enable-libbluray \
        --enable-libfdk_aac \
        --enable-libfreetype \
        --enable-libkvazaar \
        --enable-libmp3lame \
        --enable-libopencore-amrnb \
        --enable-libopencore-amrwb \
        --enable-libopenjpeg \
        --enable-libopus \
        --enable-libsrt \
        --enable-libtheora \
        --enable-libvidstab \
        --enable-libvmaf \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libwebp \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libxcb \
        --enable-libxvid \
        --enable-libzmq \
        --enable-nonfree \
        --enable-openssl \
        --enable-postproc \
        --enable-shared \
        --enable-small \
        --enable-vaapi \
        --enable-version3 \
        --extra-cflags="-I${PREFIX}/include" \
        --extra-ldflags="-L${PREFIX}/lib" \
        --extra-libs=-ldl \
        --extra-libs=-lpthread \
        --prefix="${PREFIX}" && \
        make clean && \
        make && \
        make install && \
        make tools/zmqsend && cp tools/zmqsend ${PREFIX}/bin/ && \
        make distclean && \
        hash -r && \
        cd tools && \
        make qt-faststart && cp qt-faststart ${PREFIX}/bin/

## cleanup
RUN \
        ldd ${PREFIX}/bin/ffmpeg | grep opt/ffmpeg | cut -d ' ' -f 3 | xargs -i cp {} /usr/local/lib/ && \
        for lib in /usr/local/lib/*.so.*; do ln -s "${lib##*/}" "${lib%%.so.*}".so; done && \
        cp ${PREFIX}/bin/* /usr/local/bin/ && \
        cp -r ${PREFIX}/share/ffmpeg /usr/local/share/ && \
        LD_LIBRARY_PATH=/usr/local/lib ffmpeg -buildconf && \
        cp -r ${PREFIX}/include/libav* ${PREFIX}/include/libpostproc ${PREFIX}/include/libsw* /usr/local/include && \
        mkdir -p /usr/local/lib/pkgconfig && \
        for pc in ${PREFIX}/lib/pkgconfig/libav*.pc ${PREFIX}/lib/pkgconfig/libpostproc.pc ${PREFIX}/lib/pkgconfig/libsw*.pc; do \
          sed "s:${PREFIX}:/usr/local:g" <"$pc" >/usr/local/lib/pkgconfig/"${pc##*/}"; \
        done

############## libiconv ##############
FROM base AS libiconv

RUN \
  echo "**** install basic build tools ****" && \
  apt-get update -yq && \
  apt-get install -yq --no-install-recommends \
    build-essential \
	wget

RUN \
  echo "**** libiconv source ****" && \
  wget https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.16.tar.gz -P /tmp/ && \
  mkdir -p /tmp/libiconv && \
  tar -C /tmp/libiconv -xzf /tmp/libiconv-1.16.tar.gz --strip-components=1

WORKDIR /tmp/libiconv
RUN \
  echo "**** compile libiconv ****" && \
  ./configure && \
  make VERBOSE=1 && \
  make DESTDIR=/libiconv install

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
	TVHEADEND_COMMIT=$(curl -sX GET https://api.github.com/repos/tvheadend/tvheadend/commits/master \
	| jq -r '. | .sha'); \
 fi && \
 git clone https://github.com/tvheadend/tvheadend.git /tmp/tvheadend && \
 cd /tmp/tvheadend && \
 git checkout ${TVHEADEND_COMMIT}

RUN \
  echo "**** install build-deps ****" && \
  apt-get install -yq --no-install-recommends \
    bzip2 \
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
    libavresample-dev \
    libavutil-dev \
    libswresample-dev \
    libswscale-dev && \
  echo "**** setting default /usr/bin/python ****" && \
  if [ ! -e /usr/bin/python ]; then ln -sf /usr/bin/python3 /usr/bin/python; fi

# copy deps
COPY --from=libiconv /libiconv/usr/ /usr/

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

############# comskip ##############
FROM base AS comskip

RUN \
  echo "**** install basic build tools ****" && \
  apt-get update -yq && \
  apt-get install -yq --no-install-recommends \
    autoconf \
    automake \
    build-essential \
    git \
	libtool \
	pkg-config

RUN \
  echo "***** comskip source ****" && \
  git clone https://github.com/erikkaashoek/Comskip /tmp/comskip

RUN \
  echo "**** install build-deps ****" && \
  apt-get update -yq && \
  apt-get install -yq --no-install-recommends \
	libargtable2-dev

# copy deps
COPY --from=ffmpeg /usr/local/ /usr/local/

WORKDIR /tmp/comskip
RUN \
  echo "***** compile comskip ****" && \
  ./autogen.sh && \
  ./configure \
    --bindir=/usr/bin \
    --sysconfdir=/config/comskip && \
  make && \
  make DESTDIR=/comskip install

############## collect stage ##############
FROM base AS collector

COPY --from=ffmpeg /usr/local/ /bar/usr/local/
COPY --from=libiconv /libiconv/usr/ /bar/usr/
COPY --from=tvheadend /tvheadend/usr/ /bar/usr/
COPY --from=comskip /comskip/usr/ /bar/usr/

COPY --from=ghcr.io/linuxserver/picons-builder /picons.tar.bz2 /picons.tar.bz2
RUN mkdir -p /bar/picons && tar xf /picons.tar.bz2 -C /bar/picons

COPY root/ /bar/

############## release tvhbase ##############
FROM base

ARG DEBIAN_FRONTEND="noninteractive"

# environment settings
ARG TZ="Asia/Seoul"
ENV HOME="/config"

ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64

RUN \
  echo "**** install runtime packages ****" && \
  apt-get update && \
  apt-get install -yq  --no-install-recommends \
    `# ffmpeg` \
    ca-certificates \
    expat \
    libgomp1 \
	`# comskip` \
    libargtable2-0 \
    `# tvheadend` \
    bzip2 \
    curl \
    gzip \
    libavahi-common3 \
    libavahi-client3 \
    libdvbcsa1 \
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
