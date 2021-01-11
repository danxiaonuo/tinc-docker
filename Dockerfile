##########################################
#         构建基础镜像                   #
##########################################
FROM alpine:edge
# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=C.UTF-8
ENV LANG=$LANG

# 镜像变量
ARG DOCKER_IMAGE=danxiaonuo/strongswan
ENV DOCKER_IMAGE=$DOCKER_IMAGE
ARG DOCKER_IMAGE_OS=alpine
ENV DOCKER_IMAGE_OS=$DOCKER_IMAGE_OS
ARG DOCKER_IMAGE_TAG=edge
ENV DOCKER_IMAGE_TAG=$DOCKER_IMAGE_TAG
ARG BUILD_DATE
ENV BUILD_DATE=$BUILD_DATE
ARG VCS_REF
ENV VCS_REF=$VCS_REF


# ##############################################################################

# ***** 设置变量 *****

# 构建依赖

ARG BUILD_DEPS="\
    autoconf \
	  build-base \
	  curl \
    wget \
	  g++ \
	  gcc \
	  libc-utils \
	  libpcap-dev \
	  libressl \
	  linux-headers \
	  lzo-dev \
	  make \
	  ncurses-dev \
	  openssl-dev \
	  readline-dev \
	  tar \
	  zlib-dev"
ENV BUILD_DEPS=$BUILD_DEPS

ARG RUN_DEPS="\
    ARG RUN_DEPS="\
    ca-certificates \
	  git \
	  libcrypto1.1 \
	  libpcap \
	  lzo \
	  openssl \
	  readline \
	  zlib"
ENV RUN_DEPS=$RUN_DEPS

# TINC
ARG TINC_VERSION="1.1pre17"
ENV TINC_VERSION=$TINC_VERSION

# 修改源地址
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
# ***** 安装依赖 *****
RUN set -eux \
   # 更新源地址
   && apk update \
   # 更新系统并更新系统软件
   && apk upgrade && apk upgrade \
   && apk add -U --update $BUILD_DEPS $RUN_DEPS \
   # 更新时区
   && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
   # 更新时间
   && echo ${TZ} > /etc/timezone

# 安装 TINC
RUN set -eux \
    cd /tmp && \
    wget --no-check-certificate http://www.tinc-vpn.org/packages/tinc-${TINC_VERSION}.tar.gz -O /tmp/tinc-${TINC_VERSION}.tar.gz && \
    tar zxvf tinc-${TINC_VERSION}.tar.gz && cd tinc-${TINC_VERSION} && \
    ./configure --prefix=/opt/tinc --sysconfdir=/etc --disable-lzo --enable-jumbograms --enable-tunemu && \
    make -j$(($(nproc)+1)) && \
    make -j$(($(nproc)+1)) install && \
    apk del --no-cache --purge $BUILD_DEP && \
    rm -rf /tmp/* && \
    mkdir -p /var/log/tinc && \
    rm -rf /var/cache/apk/*
    
# 设置环境
RUN echo ". /etc/profile" > /root/.bashrc
RUN echo "alias ll='ls -alF'"     >> /etc/profile
RUN echo "export PS1='\H:\w\\$ '" >> /etc/profile
RUN echo 'export TERM="xterm"'    >> /etc/profile

# 拷贝初始化脚本
COPY init.sh /init.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod a+x /init.sh && \
    chmod a+x /entrypoint.sh

# 入口
ENTRYPOINT ["/entrypoint.sh"]
