##########################################
#         构建基础镜像                   #
##########################################
FROM alpine:latest
# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=C.UTF-8
ENV LANG=$LANG

# 镜像变量
ARG DOCKER_IMAGE=danxiaonuo/tinc
ENV DOCKER_IMAGE=$DOCKER_IMAGE
ARG DOCKER_IMAGE_OS=alpine
ENV DOCKER_IMAGE_OS=$DOCKER_IMAGE_OS
ARG DOCKER_IMAGE_TAG=latest
ENV DOCKER_IMAGE_TAG=$DOCKER_IMAGE_TAG


# ##############################################################################

# ***** 设置变量 *****

# 构建依赖
ARG BUILD_DEPS="\
    automake \
    autoconf \
    libtool \
    texinfo \
    build-base \
    curl \
    wget \
    g++ \
    gcc \
    libc-utils \
    libpcap-dev \
    libressl-dev \
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
    ca-certificates \
    iproute2 \
    git \ 
    zsh \
    vim \
    libcrypto1.1 \
    libpcap \
    lzo \
    openssl \
    readline \
    zlib"
ENV RUN_DEPS=$RUN_DEPS

# TINC
# 版本号
ARG TAGS=1.1
ENV TAGS=$TAGS

# ***** 安装依赖 *****
RUN set -eux \
   # 修改源地址
   && sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
   # 更新源地址并更新系统软件
   && apk update && apk upgrade \
   # 安装依赖包
   && apk add --no-cache --clean-protected $BUILD_DEPS $RUN_DEPS \
   # 更新时区
   && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
   # 更新时间
   && echo ${TZ} > /etc/timezone \
   # vim设置
   && sed -i -e 's/mouse=/mouse-=/g' /usr/share/vim/vim*/defaults.vim \
   # 更改为zsh
   && sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true \
   && sed -i -e "s/bin\/ash/bin\/zsh/" /etc/passwd \
   && /bin/zsh

# 安装 TINC
# 克隆源码运行安装
RUN git clone --depth=1 -b ${TAGS} --progress https://github.com/gsliepen/tinc.git /src  \
    && cd /src && autoreconf -fsvdi && ./configure --prefix=/opt/tinc --sysconfdir=/etc --disable-lzo --enable-jumbograms --enable-tunemu \
    && ./configure --prefix=/opt/tinc --sysconfdir=/etc --disable-lzo --enable-jumbograms --enable-tunemu \
    && make -j$(($(nproc)+1)) \
    && make -j$(($(nproc)+1)) install \
    && ln -sf /opt/tinc/sbin/tincd /usr/bin/tincd \
    && ln -sf /opt/tinc/sbin/tinc /usr/bin/tinc \
    && mkdir -pv /etc/tinc && mkdir -pv /opt/tinc/var/run && mkdir -pv /opt/tinc/var/log \
    && apk del --no-cache --purge $BUILD_DEPS \
    && rm -rf /tmp/* /src \
    && mkdir -p /var/log/tinc \
    && rm -rf /var/cache/apk/*
    

# 拷贝初始化脚本
COPY init.sh /init.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod a+x /init.sh && \
    chmod a+x /entrypoint.sh
    
# 入口
ENTRYPOINT ["/entrypoint.sh"]
