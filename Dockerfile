FROM ubuntu:18.04 as builder

# Surpress Upstart errors/warning
RUN dpkg-divert --local --rename --add /sbin/initctl && ln -sf /bin/true /sbin/initctl

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# Update base image
# Add sources for latest nginx
# Install software requirements

ENV nginx_version 1.15.2

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

# install optional encoder
# RUN apt-get -y install software-properties-common;\
#        apt-add-repository ppa:jon-severinsson/ffmpeg;\
#        apt-get update;\
#        apt-get -y install ffmpeg

RUN \
  groupadd nginx && useradd -m -g nginx nginx && \
	apt-get update && \
	apt-get install --no-install-recommends -y git \
	wget \
      ca-certificates \
	unzip \
	automake \
	git \
	build-essential \
	libpcre3-dev \
	autotools-dev \
	libssl-dev \
	zlib1g-dev \
	libgeoip-dev \
	libxslt1-dev \
	libxml2-dev &&\
	cd /tmp && \
	wget -nd http://nginx.org/download/nginx-${nginx_version}.tar.gz && \
	tar xfz nginx-${nginx_version}.tar.gz && \
	cd /tmp && \
	git clone --verbose https://github.com/sergey-dryabzhinsky/nginx-rtmp-module && \
  cd /tmp/nginx-${nginx_version} && \
  ./configure --add-module=../nginx-rtmp-module \
        --with-http_ssl_module \
        --with-http_secure_link_module \
        --with-http_auth_request_module \
        --with-http_v2_module \
        --with-http_xslt_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_random_index_module \
        --with-http_stub_status_module \
        --with-ipv6 \
        --user=nginx \
        --group=nginx \
        --prefix=/usr/local/nginx && \
  cd /tmp/nginx-${nginx_version} && \
  make && \
  make install

# https://github.com/sergey-dryabzhinsky/nginx-rtmp-module
# https://github.com/arut/nginx-rtmp-module.git

FROM ubuntu:18.04

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION


COPY --from=0 /tmp/nginx-rtmp-module/stat.xsl /tmp/stat.xsl
COPY --from=0 /usr/local/nginx /usr/local/nginx

RUN ln -sf /dev/stdout /usr/local/nginx/logs/access.log \
	&& ln -sf /dev/stderr /usr/local/nginx/logs/error.log

RUN  groupadd nginx && useradd -m -g nginx nginx && mkdir -p /srv/www/streams	&& \
      apt-get update  && \
	apt-get install --no-install-recommends -y \
      libssl-dev \
      libxml2 \
      libxslt1.1 && \
      rm -rf /var/lib/apt/lists/*

COPY nginx.conf /usr/local/nginx/conf/nginx.conf
COPY hdw.conf /usr/local/nginx/conf/sites-enabled/hdw.conf
COPY health.conf /usr/local/nginx/conf/sites-enabled/health.conf
COPY ["run.sh", "index.html", "ihls.html", "dynamic.html", "hdw.html", "/srv/www/" ]
RUN chmod +x /srv/www/run.sh
ADD player /srv/www/player
ADD images /srv/www/images

VOLUME ["/srv/www/","/usr/local/nginx/logs", "/usr/local/nginx/conf/ssl"]

WORKDIR /srv/www
				
EXPOSE 1935 80 8080 443

CMD sh ./run.sh

LABEL "maintainer"="peuserik@peuserik.de" \
      "org.label-schema.base-image.name"="ubuntu" \
      "org.label-schema.base-image.version"="18.04" \ 
      "org.label-schema.description"="nginx with rtmp serving hls, dash and hdw players" \
      "org.label-schema.vcs-url"="https://github.com/peuserik/hdw-rtmp" \
      "org.label-schema.schema-version"="1.0.0-rc.1" \
      "org.label-schema.vcs-ref"=$VCS_REF \
      "org.label-schema.version"=$VERSION \
      "org.label-schema.build-date"=$BUILD_DATE 