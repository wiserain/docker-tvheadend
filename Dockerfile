FROM ghcr.io/linuxserver/baseimage-alpine:3.15 AS base

############## dvbapps ##############
FROM base AS dvbapps

RUN \
    echo "**** dvb-apps source ****" && \
    apk add --no-cache mercurial && \
    hg clone http://linuxtv.org/hg/dvb-apps /tmp/dvb-apps

RUN \
    echo "**** install build packages ****" && \
    apk add --no-cache \
        build-base \
        linux-headers

WORKDIR /tmp/dvb-apps
RUN \
    echo "**** compile dvb-apps ****" && \
    make -C lib && \
    make -C lib DESTDIR=/dvbapps install

############## tvheadend ##############
FROM base AS tvheadend

# environment settings
ARG TARGETARCH
ARG TVHEADEND_COMMIT

RUN \
    echo "**** tvheadend source ****" && \
    apk add --no-cache git jq && \
    if [ -z ${TVHEADEND_COMMIT+x} ]; then \
        TVHEADEND_COMMIT=$(curl -sX GET https://api.github.com/repos/tvheadend/tvheadend/commits/release/4.2 \
        | jq -r '. | .sha'); \
    fi && \
    git clone https://github.com/tvheadend/tvheadend.git /tmp/tvheadend && \
    cd /tmp/tvheadend && \
    git checkout ${TVHEADEND_COMMIT}

RUN \
    echo "**** install build packages ****" && \
    apk add --no-cache \
        autoconf \
        automake \
        bsd-compat-headers \
        cmake \
        curl \
        diffutils \
        ffmpeg-dev \
        file \
        findutils \
        g++ \
        gcc \
        gettext-dev \
        git \
        gnu-libiconv-dev \
        gzip \
        jq \
        libdvbcsa-dev \
        libgcrypt-dev \
        libressl-dev \
        libtool \
        libvpx-dev \
        libxml2-dev \
        libxslt-dev \
        linux-headers \
        make \
        mercurial \
        opus-dev \
        patch \
        pcre2-dev \
        pkgconf \
        pngquant \
        py3-requests \
        sdl-dev \
        tar \
        uriparser-dev \
        wget \
        x264-dev \
        x265-dev \
        zlib-dev && \
    echo "**** setting default /usr/bin/python ****" && \
    if [ ! -e /usr/bin/python ]; then ln -sf /usr/bin/python3 /usr/bin/python; fi

RUN \
    echo "**** remove musl iconv.h and replace with gnu-iconv.h ****" && \
    rm -rf /usr/include/iconv.h && \
    cp /usr/include/gnu-libiconv/iconv.h /usr/include/iconv.h

# copy deps
COPY --from=dvbapps /dvbapps/usr/ /usr/

# copy patches
COPY patches/*.patch /tmp/patches/

WORKDIR /tmp/tvheadend
RUN \
    echo "**** fix fails to build with -fno-common or gcc-10 ****" && \
    patch -p1 -i /tmp/patches/tvheadend-4.2.8-fno-common.patch && \ 
    echo "**** use ffmpeg>=3.4.7 to fix invalid use of av_alloc_size ****" && \
    sed -i 's/ffmpeg-3.4.5/ffmpeg-3.4.9/g' Makefile.ffmpeg && \
    sed -i 's/e8d0bb42513ce0761a500d8f83426fd035c3f1f9/09e754f4e875b368f24cb6423d6168002e41fa55/g' Makefile.ffmpeg && \
    echo "**** use libhdhomerun > 20171221 as it seems deleted from server ****" && \
    patch -p1 -i /tmp/patches/Makefile.hdhomerun.patch
RUN \
    echo "**** compile tvheadend ****" && \
    ./configure \
        `#Encoding` \
        --$([ "$TARGETARCH" = "amd64" ] && echo "en" || echo "dis")able-ffmpeg_static \
        --enable-libx264 \
        --enable-libx264_static \
        --enable-libx265 \
        --enable-libx265_static \
        --enable-libvpx \
        --enable-libvpx_static \
        --enable-libtheora \
        --enable-libtheora_static \
        --enable-libvorbis \
        --enable-libvorbis_static \
        --enable-libfdkaac \
        --enable-libfdkaac_static \
        --enable-libopus \
        --enable-libopus_static \
        \
        `#Options` \
        --disable-bintray_cache \
        --enable-dvbcsa \
        --enable-hdhomerun_static \
        --enable-hdhomerun_client \
        --enable-libav \
        --enable-pngquant \
        --enable-trace \
        --infodir=/usr/share/info \
        --localstatedir=/var \
        --mandir=/usr/share/man \
        $([ "$TARGETARCH" = "arm" ] && echo "--nowerror")  \
        --prefix=/usr \
        --python=python3 \
        --sysconfdir=/config && \
    make -j$(nproc) && \
    make DESTDIR=/tvheadend install

############## argtable ##############
FROM base AS argtable

# package versions
ARG ARGTABLE_VER="2.13"

RUN \
    echo "**** argtable2 source ****" && \
    ARGTABLE_VER1="${ARGTABLE_VER//./-}" && \
    mkdir -p \
        /tmp/argtable && \
    curl -o \
        /tmp/argtable-src.tar.gz -L \
        "https://sourceforge.net/projects/argtable/files/argtable/argtable-${ARGTABLE_VER}/argtable${ARGTABLE_VER1}.tar.gz" && \
    tar xf /tmp/argtable-src.tar.gz \
        -C /tmp/argtable \
        --strip-components=1

# copy patches
COPY patches/config.* /tmp/argtable/

RUN \
    echo "**** install build packages ****" && \
    apk add --no-cache \
        build-base

WORKDIR /tmp/argtable
RUN \
    echo "**** compile argtable2 ****" && \
    ./configure \
        --prefix=/usr && \
    make -j$(nproc) && \
    make check && \
    make DESTDIR=/argtable install

############# comskip ##############
FROM base AS comskip

RUN \
    echo "***** comskip source ****" && \
    apk add --no-cache git && \
    git clone https://github.com/erikkaashoek/Comskip /tmp/comskip --depth=1

RUN \
    echo "**** install build packages ****" && \
    apk add --no-cache \
        autoconf \
        automake \
        build-base \
        ffmpeg-dev \
        libtool \
        pkgconf

# copy deps
COPY --from=argtable /argtable/usr/ /usr/

WORKDIR /tmp/comskip
RUN \
    echo "***** compile comskip ****" && \
    ./autogen.sh && \
    ./configure \
        --bindir=/usr/bin \
        --sysconfdir=/config/comskip && \
    make -j$(nproc) && \
    make DESTDIR=/comskip install

############## collect stage ##############
FROM base AS collector

COPY --from=dvbapps /dvbapps/usr/ /bar/usr/
COPY --from=tvheadend /tvheadend/usr/ /bar/usr/
COPY --from=argtable /argtable/usr/lib/ /bar/usr/lib/
COPY --from=comskip /comskip/usr/ /bar/usr/

COPY --from=ghcr.io/linuxserver/picons-builder /picons.tar.bz2 /picons.tar.bz2
RUN mkdir -p /bar/picons && tar xf /picons.tar.bz2 -C /bar/picons

COPY root/ /bar/

############## runtime stage ##############
FROM base

# environment settings
ENV HOME="/config"

RUN \
    echo "**** install runtime packages ****" && \
    apk add --no-cache \
        bsd-compat-headers \
        curl \
        ffmpeg \
        gnu-libiconv \
        gzip \
        libcrypto1.1 \
        libcurl \
        libdvbcsa \
        libressl \
        libssl1.1 \
        libvpx \
        libxml2 \
        libxslt \
        linux-headers \
        opus \
        pcre2 \
        py3-requests \
        tar \
        uriparser \
        wget \
        x264 \
        x265 \
        xmltv \
        zlib && \
    echo "**** setting default /usr/bin/python ****" && \
    if [ ! -e /usr/bin/python ]; then ln -sf /usr/bin/python3 /usr/bin/python; fi && \
    python3 -m ensurepip && \
    rm -r /usr/lib/python*/ensurepip && \
    pip3 install --no-cache --upgrade pip setuptools wheel

# copy local files and buildstage artifacts
COPY --from=collector /bar/ /

# ports and volumes
EXPOSE 9981 9982
VOLUME /config
