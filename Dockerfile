# LICENSE UPL 1.0
#
# Copyright (c) 2015 Oracle and/or its affiliates. All rights reserved.
#

FROM alpine:3.11

# Note: If you are behind a web proxy, set the build variables for the build:
#       E.g.:  docker build --build-arg "https_proxy=..." --build-arg "http_proxy=..." --build-arg "no_proxy=..." ...
LABEL \
    org.opencontainers.image.url='https://github.com/graalvm/container' \
    org.opencontainers.image.source='https://github.com/graalvm/container/tree/master/community' \
    org.opencontainers.image.title='GraalVM Community Edition' \
    org.opencontainers.image.authors='GraalVM Sustaining Team <graalvm-sustaining_ww_grp@oracle.com>' \
    org.opencontainers.image.description='GraalVM is a universal virtual machine for running applications written in JavaScript, Python, Ruby, R, JVM-based languages like Java, Scala, Clojure, Kotlin, and LLVM-based languages such as C and C++.'
    
RUN apk update \
    && apk add --no-cache bash dpkg curl bzip2-dev ed gcc build-base g++ gfortran gzip file fontconfig less libcurl curl-dev make openssl openssl-dev readline-dev tar vim which xz-dev zlib-dev \
    && apk add --no-cache glib-static llvm zlib-static \
    && apk -U add findutils

# Install alpine-pkg-glibc https://github.com/sgerrand/alpine-pkg-glibc
RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.33-r0/glibc-2.33-r0.apk && \
    apk add glibc-2.33-r0.apk

# Install glibc-i18n & localedef to generate locales https://github.com/sgerrand/alpine-pkg-glibc#locales
RUN wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.33-r0/glibc-bin-2.33-r0.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.33-r0/glibc-i18n-2.33-r0.apk && \
    apk add glibc-bin-2.33-r0.apk glibc-i18n-2.33-r0.apk && \
    /usr/glibc-compat/bin/localedef -i en_US -f UTF-8 en_US.UTF-8
    
# Install libz package
RUN wget "https://www.archlinux.org/packages/core/x86_64/zlib/download" -O /tmp/libz.tar.xz \
    && mkdir -p /tmp/libz \
    && tar -xf /tmp/libz.tar.xz -C /tmp/libz \
    && cp /tmp/libz/usr/lib/libz.so.1.2.11 /usr/glibc-compat/lib \
    && /usr/glibc-compat/sbin/ldconfig \
    && rm -rf /tmp/libz /tmp/libz.tar.xz

RUN fc-cache -f -v

ARG GRAALVM_VERSION=21.1.0
ARG JAVA_VERSION=java11
ARG GRAALVM_PKG=https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-$GRAALVM_VERSION/graalvm-ce-$JAVA_VERSION-GRAALVM_ARCH-$GRAALVM_VERSION.tar.gz
ARG TARGETPLATFORM

ENV LANG=C.UTF-8 \
    JAVA_HOME=/opt/graalvm-ce-$JAVA_VERSION-$GRAALVM_VERSION/

ADD gu-wrapper.sh /usr/local/bin/gu
RUN set -eux \
    && if [ "$TARGETPLATFORM" == "linux/amd64" ]; then GRAALVM_PKG=${GRAALVM_PKG/GRAALVM_ARCH/linux-amd64}; fi \
    && if [ "$TARGETPLATFORM" == "linux/arm64" ]; then GRAALVM_PKG=${GRAALVM_PKG/GRAALVM_ARCH/linux-aarch64}; fi \
    && curl --fail --location --retry 3 ${GRAALVM_PKG} \
    | gunzip | tar x -C /opt/ \

    # Set alternative links
    && mkdir -p "/usr/java" \
    && ln -sfT "$JAVA_HOME" /usr/java/default \
    && ln -sfT "$JAVA_HOME" /usr/java/latest \
    && for bin in "$JAVA_HOME/bin/"*; do \
        base="$(basename "$bin")"; \
        [ ! -e "/usr/bin/$base" ]; \
        update-alternatives  --install "/usr/bin/$base" "$base" "$bin" 20000; \
        update-alternatives --set $base $bin; \
        echo $bin $base; \
    done \

    && chmod +x /usr/local/bin/gu

CMD java -version
