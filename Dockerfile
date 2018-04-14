FROM ubuntu:16.04

# Surpress Upstart errors/warning
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# Update base image
# Add sources for latest nginx
# Install software requirements
RUN \ 
  apt-get update && \
	apt-get upgrade -y && \
	apt-get autoremove -y && \
	apt-get clean && \
	apt-get autoclean

ENV nginx_version 1.12.2
RUN groupadd nginx && useradd -m -g nginx nginx

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

# install optional encoder
# RUN apt-get -y install software-properties-common;\
#        apt-add-repository ppa:jon-severinsson/ffmpeg;\
#        apt-get update;\
#        apt-get -y install ffmpeg

RUN \
	apt-get update && \
	apt-get install -y git \
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
	rm -rf nginx-${nginx_version}.tar.gz && \
	cd /tmp && \
	git clone --verbose https://github.com/sergey-dryabzhinsky/nginx-rtmp-module && \
  cp /tmp/nginx-rtmp-module/stat.xsl /tmp/ && \
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
        --prefix=/usr/local/nginx \
        --sbin-path=/usr/sbin && \
  cd /tmp/nginx-${nginx_version} && \
  make && \
  make install && \
  rm -rf /tmp/nginx-${nginx_version} && \
  apt-get remove --purge -y \
        wget \
        unzip \
        automake \
        build-essential \
        libpcre3-dev \
        autotools-dev \
        libssl-dev \
        autotools-dev \
        zlib1g-dev && \
  apt-get autoremove -y && \
  apt-get clean && \
  apt-get autoclean
# https://github.com/sergey-dryabzhinsky/nginx-rtmp-module
# https://github.com/arut/nginx-rtmp-module.git

RUN ln -sf /dev/stdout /usr/local/nginx/logs/access.log \
	&& ln -sf /dev/stderr /usr/local/nginx/logs/error.log

RUN mkdir -p /srv/www/	
COPY nginx.conf /usr/local/nginx/conf/nginx.conf
COPY hdw.conf /usr/local/nginx/conf/sites-enabled/hdw.conf
COPY ["run.sh", "index.html", "mobile.html", "iphone.html", "/srv/www/" ]
RUN chmod +x /srv/www/run.sh
ADD player /srv/www/player

VOLUME ["/srv/www/","/usr/local/nginx/logs"]

WORKDIR /srv/www
				
EXPOSE 1935 80 443

CMD sh ./run.sh

LABEL "maintainer"="peuserik@peuserik.de" \
      "org.label-schema.base-image.name"="ubuntu" \
      "org.label-schema.base-image.version"="16.04" \ 
      "org.label-schema.description"="nginx with rtmp serving hls, dash and hdw players" \
      "org.label-schema.vcs-url"="https://github.com/peuserik/hdw-rtmp" \
      "org.label-schema.schema-version"="1.0.0-rc.1" \
      "org.label-schema.vcs-ref"=$VCS_REF \
      "org.label-schema.version"=$VERSION \
      "org.label-schema.build-date"=$BUILD_DATE 
