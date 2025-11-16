FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive \
    KERNEL_VERSION=6.8.2 \
    SCB_NAME_PREFIX=linux-base \
    OUTPUT_DIR=/out \
    BUILD_DIR=/build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential flex bison libssl-dev libelf-dev \
    libncurses-dev bc wget xz-utils ca-certificates \
    fakeroot rsync file \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p $OUTPUT_DIR $BUILD_DIR/src
WORKDIR $BUILD_DIR

COPY build.sh /usr/local/bin/build.sh
RUN chmod +x /usr/local/bin/build.sh

ENTRYPOINT ["/usr/local/bin/build.sh"]
