# package version
ARG BASE_IMAGE
FROM $BASE_IMAGE
LABEL maintainer="wiserain"
LABEL org.opencontainers.image.source=https://github.com/wiserain/docker-tvheadend

# default variables
ENV TZ="Asia/Seoul" \
    EPG2XML_CONFIG="/epg2xml/epg2xml.json" \
    EPG2XML_CHANNELFILE="/epg2xml/Channel.json" \
    EPG2XML_XMLFILE="/epg2xml/xml/xmltv.xml"

# copy local files
COPY root/ /

RUN \
    echo "**** set permissions on tv_grab_files ****" && \
    chmod 555 /usr/bin/tv_grab_* && \
    echo "**** remove irrelevant grabbers ****" && \
    xargs rm -f < /tmp/tv_grab_irr.list && \
    echo "**** install dependencies for epg2xml" && \
    apk add --no-cache \
        git \
        jq \
        python3 \
        py3-beautifulsoup4 \
        py3-lxml \
        py3-requests \
        perl-xml-twig && \
    echo "**** install epg2xml ****" && \
    EPG2XML_VER=$(wget --no-check-certificate -O - -o /dev/null "https://api.github.com/repos/epg2xml/epg2xml/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]') && \
    python3 -m pip install "epg2xml[lxml] @ git+https://github.com/epg2xml/epg2xml.git@${EPG2XML_VER}" && \
    echo "**** cleanup ****" && \
    rm -rf \
        /tmp/* \
        /var/cache/apk/*

# ports and volumes
EXPOSE 9981 9982 9983
VOLUME /config /epg2xml
