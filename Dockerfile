FROM ghcr.io/linuxserver/baseimage-alpine:3.12 as baseimage
FROM baseimage as buildstage
############## build stage ##############

# package versions
ARG ARGTABLE_VER="2.13"

# environment settings
ARG MAKEFLAGS="-j2"
ARG TARGETARCH
ARG TVHEADEND_COMMIT

# copy patches
COPY patches/ /tmp/patches/

RUN \
 echo "**** install build packages ****" && \
 apk add --no-cache \
	autoconf \
	automake \
	bsd-compat-headers \
	bzip2 \
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

RUN \
 echo "**** compile dvb-apps ****" && \
 hg clone http://linuxtv.org/hg/dvb-apps /tmp/dvb-apps && \
 cd /tmp/dvb-apps && \
 make -C lib && \
 make -C lib DESTDIR=/tmp/dvbapps-build install && \
 cp -pr /tmp/dvbapps-build/usr/* /usr/

RUN \
 echo "**** compile tvheadend ****" && \
 if [ -z ${TVHEADEND_COMMIT+x} ]; then \
	TVHEADEND_COMMIT=$(curl -sX GET https://api.github.com/repos/tvheadend/tvheadend/commits/release/4.2 \
	| jq -r '. | .sha'); \
 fi && \
 mkdir -p \
        /tmp/tvheadend && \
 git clone https://github.com/tvheadend/tvheadend.git /tmp/tvheadend && \
 cd /tmp/tvheadend && \
 git checkout ${TVHEADEND_COMMIT} && \
 echo "**** fix fails to build with -fno-common or gcc-10 ****" && \
 patch -p1 -i /tmp/patches/tvheadend-4.2.8-fno-common.patch && \ 
 echo "**** use ffmpeg>=3.4.7 to fix invalid use of av_alloc_size ****" && \
 sed -i 's/ffmpeg-3.4.5/ffmpeg-3.4.8/g' Makefile.ffmpeg && \
 sed -i 's/e8d0bb42513ce0761a500d8f83426fd035c3f1f9/9aafbab6ddd2d8aa3d80b779d595854441ef0c07/g' Makefile.ffmpeg && \
 echo "**** use libhdhomerun > 20171221 as it seems deleted from server ****" && \
 sed -i 's/libhdhomerun_20171221/libhdhomerun_20180327/g' Makefile.hdhomerun && \
 sed -i 's/6b019728eadea3af7a5686ed5ba44e970bca7365/a6b0ce4a8b5ea103a9de2d1d9cada4b36e13c74f/g' Makefile.hdhomerun && \
 ./configure \
	`#Encoding` \
	--$(if [ "$TARGETARCH" = "amd64" ]; then echo "en"; else echo "dis"; fi)able-ffmpeg_static \
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
	--enable-bundle \
	--enable-dvbcsa \
	--enable-hdhomerun_static \
	--enable-hdhomerun_client \
	--enable-libav \
	--enable-pngquant \
	--enable-trace \
	--infodir=/usr/share/info \
	--localstatedir=/var \
	--mandir=/usr/share/man \
	--prefix=/usr \
	--python=python3 \
	--sysconfdir=/config && \
 make && \
 make DESTDIR=/tmp/tvheadend-build install

RUN \
 echo "**** compile argtable2 ****" && \
 ARGTABLE_VER1="${ARGTABLE_VER//./-}" && \
 mkdir -p \
	/tmp/argtable && \
 curl -o \
 /tmp/argtable-src.tar.gz -L \
	"https://sourceforge.net/projects/argtable/files/argtable/argtable-${ARGTABLE_VER}/argtable${ARGTABLE_VER1}.tar.gz" && \
 tar xf \
 /tmp/argtable-src.tar.gz -C \
	/tmp/argtable --strip-components=1 && \
 cp /tmp/patches/config.* /tmp/argtable && \
 cd /tmp/argtable && \
 ./configure \
	--prefix=/usr && \
 make && \
 make check && \
 make DESTDIR=/tmp/argtable-build install && \
 echo "**** copy to /usr for comskip dependency ****" && \
 cp -pr /tmp/argtable-build/usr/* /usr/

RUN \
 echo "***** compile comskip ****" && \
 git clone git://github.com/erikkaashoek/Comskip /tmp/comskip && \
 cd /tmp/comskip && \
 ./autogen.sh && \
 ./configure \
	--bindir=/usr/bin \
	--sysconfdir=/config/comskip && \
 make && \
 make DESTDIR=/tmp/comskip-build install

############## runtime stage ##############
FROM baseimage

# environment settings
ENV HOME="/config"

RUN \
 echo "**** install runtime packages ****" && \
 apk add --no-cache \
	bsd-compat-headers \
	bzip2 \
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
 pip3 install --no-cache --upgrade pip setuptools wheel && \
 echo "**** Add Picons ****" && \
 mkdir -p /picons && \
 curl -o \
	/picons.tar.bz2 -L \
	https://lsio-ci.ams3.digitaloceanspaces.com/picons/picons.tar.bz2

# copy local files and buildstage artifacts
COPY --from=buildstage /tmp/argtable-build/usr/ /usr/
COPY --from=buildstage /tmp/comskip-build/usr/ /usr/
COPY --from=buildstage /tmp/dvbapps-build/usr/ /usr/
COPY --from=buildstage /tmp/tvheadend-build/usr/ /usr/
COPY root/ /

# ports and volumes
EXPOSE 9981 9982
VOLUME /config
