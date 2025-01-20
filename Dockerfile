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

# ############## build ffmpeg ##############
# https://github.com/jrottenberg/ffmpeg/blob/main/docker-images/6.1/vaapi2404/Dockerfile
FROM base AS ffmpeg

WORKDIR     /tmp/workdir

ADD https://raw.githubusercontent.com/jrottenberg/ffmpeg/refs/heads/main/docker-images/6.1/vaapi2404/generate-source-of-truth-ffmpeg-versions.py /tmp/workdir
ADD https://raw.githubusercontent.com/jrottenberg/ffmpeg/refs/heads/main/docker-images/6.1/vaapi2404/download_tarballs.sh /tmp/workdir
ADD https://raw.githubusercontent.com/jrottenberg/ffmpeg/refs/heads/main/docker-images/6.1/vaapi2404/build_source.sh /tmp/workdir
ADD https://raw.githubusercontent.com/jrottenberg/ffmpeg/refs/heads/main/docker-images/6.1/vaapi2404/install_ffmpeg.sh /tmp/workdir


ENV FFMPEG_VERSION=6.1.2

## opencore-amr - https://sourceforge.net/projects/opencore-amr/
##         x264 - http://www.videolan.org/developers/x264.html
##         x265 - http://x265.org/ ( videolan )
##       libogg - https://www.xiph.org/ogg/ ( xiph )
##      libopus - https://www.opus-codec.org/ ( xiph )
##              - https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu#libopus
##    libvorbis - https://xiph.org/vorbis/ ( xiph )
##       libvpx - https://www.webmproject.org/code/
##              - https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu#libvpx
##      libwebp - https://developers.google.com/speed/webp/
##   libmp3lame - http://lame.sourceforge.net/
##         xvid - https://www.xvid.com/ (xvidcore)
##      fdk-aac - https://github.com/mstorsjo/fdk-aac
##              - https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu#libfdk-aac
##     openjpeg - https://github.com/uclouvain/openjpeg
##     freetype - https://www.freetype.org/
##                consider passing --no-install-recommends for this one its globbie (if you do, pass in libfreetype6)
##   libvidstab - https://github.com/georgmartius/vid.stab
##      fridibi - https://www.fribidi.org/
##   fontconfig - https://www.freedesktop.org/wiki/Software/fontconfig/
##       libass - https://github.com/libass/libass
##      lib aom - https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu#libaom
##    libsvtav1 - https://gitlab.com/AOMediaCodec/SVT-AV1.git
##              - https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu#libsvtav1
##     libdav1d - https://code.videolan.org/videolan/dav1d
##              - https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu#libdav1d
##  util-macros - (x.org) (and supporting libraries) for screen capture https://xcb.freedesktop.org/
##       xproto - (x.org)
##       libXau -
##   libpthread - libpthread-stubs
##      libxml2 - for libbluray
##    libbluray - Requires libxml, freetype, and fontconfig
##       libzmq - https://github.com/zeromq/libzmq/
##                this one pulls in a bunch of dependencies
##       libpng - this one also pulls in a bunch of stuff
##   libaribb24 -
##         zimg - https://github.com/sekrit-twc/zimg
##    libtheora - http://www.theora.org/ ( xiph )
##              - https://stackoverflow.com/questions/4810996/how-to-resolve-configure-guessing-build-type-failure
##       libsrt - https://github.com/Haivision/srt
##                Secure Reliable Transport UDP streaming library
##                multiple flavors (OpenSSL flavour) and ( GnuTLS flavour)
ARG OPENCORE_PKGS="libopencore-amrnb-dev libopencore-amrnb0 libopencore-amrwb-dev libopencore-amrwb0"
ARG X264_PKGS="libx264-164 libx264-dev"
ARG X265_PKGS="libnuma1 libx265-199 libx265-dev"
# libnuma-dev
ARG OGG_PKGS="libogg-dev libogg0"
ARG OPUS_PKGS="libopus-dev libopus0"
ARG VORBIS_PKGS="libvorbis-dev libvorbis0a libvorbisenc2 libvorbisfile3"
ARG VPX_PKGS="libvpx-dev libvpx9"
ARG WEBP_PKGS="libsharpyuv-dev libsharpyuv0 libwebp-dev libwebp7 libwebpdecoder3 libwebpdemux2 libwebpmux3"
ARG MP3LAME_PKGS="libmp3lame-dev libmp3lame0"
ARG XVIDCORE_PKGS="libxvidcore-dev libxvidcore4"
ARG FDKAAC_PKGS="libfdk-aac-dev libfdk-aac2"
ARG OPENJP_PKGS="libopenjp2-7 libopenjp2-7-dev"
# bzip2-doc fontconfig-config fonts-dejavu-core fonts-dejavu-mono libaom3 libbrotli-dev
# libbrotli1 libbsd0 libbz2-dev libc-dev-bin libc-devtools libc6-dev libcrypt-dev libde265-0
# libdeflate0 libfontconfig1 libfreetype6 libgd3 libheif-plugin-aomdec
# libheif-plugin-aomenc libheif-plugin-libde265 libheif1 libjbig0 libjpeg-turbo8
# libjpeg8 liblerc4 libpng-dev libpng-tools libpng16-16t64 libsharpyuv0 libtiff6
#  libwebp7 libx11-6 libx11-data libxau6 libxcb1 libxdmcp6 libxpm4 linux-libc-dev
# manpages manpages-dev rpcsvc-proto zlib1g-dev
ARG FREETYPE_PKGS="libfreetype6-dev"
ARG FONTCONFIG_PKGS="fontconfig libfontconfig-dev libfontconfig1 fontconfig-config fonts-dejavu-core fonts-dejavu-mono"
ARG VIDSTAB_PKGS="libvidstab-dev libvidstab1.1"
ARG FRIBIDI_PKGS="libfribidi-dev libfribidi0"
# libass-dev wanted to install a boat-load of packages
ARG LIBASS_PKGS="libass-dev libass9"
ARG AOM_PKGS="libaom-dev libaom3"
ARG SVTAV1_PKGS="libsvtav1-dev libsvtav1enc-dev libsvtav1enc1d1 libsvtav1dec-dev libsvtav1dec0"
ARG DAV1D_PKGS="libdav1d-dev libdav1d7"
# LIBDRM_PKGS picks ups some of the XORG_MACROS_PKGS as well
ARG XORG_MACROS_PKGS="libxcb-shm0-dev libxcb-shm0 libxcb-xfixes0 libxcb-xfixes0-dev"
ARG XPROTO_PKGS="x11proto-core-dev x11proto-dev"
ARG XAU_PKGS="libxau-dev libxau6"
ARG PTHREADS_STUBS_PKGS="libpthread-stubs0-dev"
ARG XML2_PKGS="libxml2-dev libxml2"
ARG BLURAY_PKGS="libbluray-dev libbluray2"
ARG ZMQ_PKGS="libzmq3-dev libzmq5"
# libpng-tools
ARG PNG_PKGS="libpng-dev libpng16-16t64"
ARG ARIBB24_PKGS="libaribb24-dev"
ARG ZIMG_PKGS="libzimg-dev libzimg2"
ARG THEORA_PKGS="libtheora-dev libtheora0"
ARG SRT_PKGS="libssl-dev libsrt-openssl-dev libsrt1.5-openssl"
ARG LIBDRM_PKGS="libbsd0 libdrm-dev libdrm2 libxcb1-dev libxcb1"

ENV MAKEFLAGS="-j2"
ENV PKG_CONFIG_PATH="/opt/ffmpeg/share/pkgconfig:/opt/ffmpeg/lib/pkgconfig:/opt/ffmpeg/lib64/pkgconfig:/opt/ffmpeg/lib/x86_64-linux-gnu/pkgconfig:/opt/ffmpeg/lib/aarch64-linux-gnu/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig"

ENV PREFIX="/opt/ffmpeg"
ENV LD_LIBRARY_PATH="/opt/ffmpeg/lib:/opt/ffmpeg/lib64:/opt/ffmpeg/lib/aarch64-linux-gnu"


ARG DEBIAN_FRONTEND=noninteractive

# Before autoremove and clean: Image was 217.01MB
RUN     apt-get -yqq update && \
        apt-get install -yq --no-install-recommends curl jq python3 python3-requests less tree file vim && \
        chmod +x /tmp/workdir/generate-source-of-truth-ffmpeg-versions.py && \
        chmod +x /tmp/workdir/download_tarballs.sh && \
        chmod +x /tmp/workdir/build_source.sh && \
        chmod +x /tmp/workdir/install_ffmpeg.sh

RUN      buildDeps="autoconf \
                    automake \
                    cmake \
                    build-essential \
                    texinfo \
                    curl \
                    wget \
                    tar \
                    bzip2 \
                    libexpat1-dev \
                    gcc \
                    git \
                    git-core \
                    gperf \
                    libtool \
                    make \
                    meson \
                    ninja-build \
                    nasm \
                    perl \
                    pkg-config \
                    python3 \
                    yasm \
                    zlib1g-dev \
                    libfreetype6-dev \
                    libgnutls28-dev \
                    libsdl2-dev \
                    libva-dev \
                    libvdpau-dev \
                    libnuma-dev \
                    libdav1d-dev \
                    openssl \
                    libssl-dev \
                    expat \
                    libgomp1" && \
        apt-get -yqq update && \
        apt-get install -yq --no-install-recommends ${buildDeps}

RUN \
        echo "Installing dependencies..." && \
        apt-get install -yq --no-install-recommends ${OPENCORE_PKGS} ${X264_PKGS} ${X265_PKGS} ${OGG_PKGS} ${OPUS_PKGS} ${VORBIS_PKGS} ${VPX_PKGS} ${WEBP_PKGS} ${MP3LAME_PKGS} ${XVIDCORE_PKGS} ${FDKAAC_PKGS} ${OPENJP_PKGS} ${FREETYPE_PKGS} ${VIDSTAB_PKGS} ${FRIBIDI_PKGS} ${FONTCONFIG_PKGS} ${LIBASS_PKGS} ${AOM_PKGS} ${SVTAV1_PKGS} ${DAV1D_PKGS} ${XORG_MACROS_PKGS} ${XPROTO_PKGS} ${XAU_PKGS} ${PTHREADS_STUBS_PKGS} ${XML2_PKGS} ${BLURAY_PKGS} ${ZMQ_PKGS} ${PNG_PKGS} ${ARIBB24_PKGS} ${ZIMG_PKGS} ${THEORA_PKGS} ${SRT_PKGS} ${LIBDRM_PKGS}

RUN \
	apt-get install -y --no-install-recommends libva-drm2 libva2 i965-va-driver

        # apt install libdrm-dev

## libvmaf https://github.com/Netflix/vmaf
## https://github.com/Netflix/vmaf/issues/788#issuecomment-756098059
RUN \
        echo "Adding g++ for VMAF build" && \
        apt-get install -yq g++

# Note: pass '--library-list lib1,lib2,lib3 for more control.
#       Here we have 3 libs that we have to build from source
RUN /tmp/workdir/generate-source-of-truth-ffmpeg-versions.py --library-list kvazaar,libvmaf
RUN /tmp/workdir/download_tarballs.sh
RUN /tmp/workdir/build_source.sh

RUN /tmp/workdir/generate-source-of-truth-ffmpeg-versions.py --library-list ffmpeg-6.1
RUN /tmp/workdir/download_tarballs.sh
RUN /tmp/workdir/build_source.sh


## when  debugging you can pass in || true to the end of the command
## to keep the build going even if one of the steps fails
RUN /tmp/workdir/install_ffmpeg.sh

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
    wget https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.18.tar.gz -P /tmp/ && \
    mkdir -p /tmp/libiconv && \
    tar -C /tmp/libiconv -xzf /tmp/libiconv-1.18.tar.gz --strip-components=1

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

COPY --from=ffmpeg /usr/share/fonts /bar/usr/share/fonts
COPY --from=ffmpeg /usr/share/fontconfig /bar/usr/share/fontconfig
COPY --from=ffmpeg /usr/bin/fc-* /bar/usr/bin/
COPY --from=ffmpeg /usr/local /bar/usr/local/
COPY --from=libiconv /libiconv/usr/ /bar/usr/
COPY --from=tvheadend /tvheadend/usr/ /bar/usr/
COPY --from=libdvbcsa /libdvbcsa/usr/ /bar/usr/
COPY --from=comskip /comskip/usr/ /bar/usr/

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
RUN ldconfig

# ports and volumes
EXPOSE 9981 9982
VOLUME /config
