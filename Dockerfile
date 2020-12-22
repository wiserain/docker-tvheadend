FROM ghcr.io/linuxserver/baseimage-alpine:3.10 as buildstage
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
	python \
	sdl-dev \
	tar \
	uriparser-dev \
	wget \
	x264-dev \
	x265-dev \
	zlib-dev

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
FROM ghcr.io/linuxserver/baseimage-alpine:3.10

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
	python \
	tar \
	uriparser \
	wget \
	x264 \
	x265 \
	xmltv \
	zlib && \
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
