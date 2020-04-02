# package version
ARG BASE_IMAGE
ARG BUILD_DATE
FROM $BASE_IMAGE
LABEL maintainer="wiserain"
LABEL build_date="${BUILD_DATE}"

# default variables
ENV UPDATE_EPG2XML="1"
ENV UPDATE_CHANNEL="1"
ENV TZ="Asia/Seoul"

# copy local files
COPY root/ /

RUN \
	echo "**** set permissions on tv_grab_files ****" && \
	chmod 555 /usr/bin/tv_grab_* && \
	echo "**** remove irrelevant grabbers ****" && \
	xargs rm < /tmp/tv_grab_irr.list && \
	echo "install dependencies for epg2xml" && \
	apk add --no-cache \
		git \
		jq \
		python3 \
		py3-beautifulsoup4 \
		py3-lxml \
		py3-requests \
		perl-xml-twig && \
	echo "**** cleanup ****" && \
	rm -rf /var/cache/apk/* && \
		rm -rf /tmp/*

# ports and volumes
EXPOSE 9981 9982 9983
VOLUME /config /epg2xml
WORKDIR /epg2xml
