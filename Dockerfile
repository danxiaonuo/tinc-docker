#############################
#     设置公共的变量         #
#############################
ARG BASE_IMAGE_TAG=22.04
FROM ubuntu:${BASE_IMAGE_TAG}

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=zh_CN.UTF-8
ENV LANG=$LANG

# 镜像变量
ARG DOCKER_IMAGE=danxiaonuo/tinc
ENV DOCKER_IMAGE=$DOCKER_IMAGE
ARG DOCKER_IMAGE_OS=ubuntu
ENV DOCKER_IMAGE_OS=$DOCKER_IMAGE_OS
ARG DOCKER_IMAGE_TAG=22.04
ENV DOCKER_IMAGE_TAG=$DOCKER_IMAGE_TAG

# TINC
# 版本号
ARG TAGS=release-1.1pre18
ENV TAGS=$TAGS

# 环境设置
ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=$DEBIAN_FRONTEND

# 构建依赖
ARG BUILD_DEPS="\
    apt-utils \
    build-essential \
    libncurses5-dev \
    libreadline6-dev \
    libzlcore-dev \
    zlib1g-dev \
    liblzo2-dev \
    libssl-dev \
    autoconf \
    automake \
    libpcap-dev \
    texinfo"
ENV BUILD_DEPS=$BUILD_DEPS
# 安装依赖包
ARG PKG_DEPS="\
    zsh \
    bash \
    bash-completion \
    dnsutils \
    iproute2 \
    net-tools \
    ncat \
    git \
    vim \
    tzdata \
    curl \
    wget \
    axel \
    lsof \
    zip \
    unzip \
    rsync \
    iputils-ping \
    telnet \
    procps \
    libaio1 \
    numactl \
    xz-utils \
    gnupg2 \
    psmisc \
    libmecab2 \
    debsums \
    locales \
    iptables \
    language-pack-zh-hans \
    fonts-droid-fallback \
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    fonts-arphic-ukai \
    fonts-arphic-uming \
    ca-certificates"
ENV PKG_DEPS=$PKG_DEPS

# ***** 安装依赖 *****
RUN set -eux && \
   # 更新源地址
   sed -i s@http://*.*ubuntu.com@https://mirrors.aliyun.com@g /etc/apt/sources.list && \
   # 解决证书认证失败问题
   touch /etc/apt/apt.conf.d/99verify-peer.conf && echo >>/etc/apt/apt.conf.d/99verify-peer.conf "Acquire { https::Verify-Peer false }" && \
   # 更新源地址并更新系统软件
   DEBIAN_FRONTEND=noninteractive apt-get update -qqy && apt-get upgrade -qqy && \
   # 安装依赖包
   DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends $BUILD_DEPS $PKG_DEPS && \
   DEBIAN_FRONTEND=noninteractive apt-get -qqy --no-install-recommends autoremove --purge && \
   DEBIAN_FRONTEND=noninteractive apt-get -qqy --no-install-recommends autoclean && \
   rm -rf /var/lib/apt/lists/* && \
   # 更新时区
   ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
   # 更新时间
   echo ${TZ} > /etc/timezone && \
   # 更改为zsh
   sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true && \
   sed -i -e "s/bin\/ash/bin\/zsh/" /etc/passwd && \
   sed -i -e 's/mouse=/mouse-=/g' /usr/share/vim/vim*/defaults.vim && \
   locale-gen zh_CN.UTF-8 && localedef -f UTF-8 -i zh_CN zh_CN.UTF-8 && locale-gen && \
   /bin/zsh
   
# 安装 TINC
# 克隆源码运行安装
RUN git clone --depth=1 -b ${TAGS} --progress https://github.com/gsliepen/tinc.git /src &&  \
    cd /src && autoreconf -fsvdi && ./configure --prefix=/opt/tinc --sysconfdir=/etc --disable-lzo --enable-jumbograms --enable-tunemu &&  \
    ./configure --prefix=/opt/tinc --sysconfdir=/etc --disable-lzo --enable-jumbograms --enable-tunemu &&  \
    make -j$(($(nproc)+1)) &&  \
    make -j$(($(nproc)+1)) install &&  \
    ln -sf /opt/tinc/sbin/tincd /usr/bin/tincd &&  \
    ln -sf /opt/tinc/sbin/tinc /usr/bin/tinc &&  \
    mkdir -pv /etc/tinc && mkdir -pv /opt/tinc/run && mkdir -pv /opt/tinc/logs && \
    DEBIAN_FRONTEND=noninteractive apt-get -qqy --no-install-recommends autoremove --purge $BUILD_DEPS && \
    rm -rf /tmp/* /src && \
    mkdir -p /var/log/tinc && \
    rm -rf /var/cache/apk/*
    
# 拷贝初始化脚本
COPY init.sh /init.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod a+x /init.sh && \
    chmod a+x /entrypoint.sh
    
# 入口
ENTRYPOINT ["/entrypoint.sh"]
