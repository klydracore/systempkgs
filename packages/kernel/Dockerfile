FROM debian:stable-slim

RUN apt-get update && apt-get install -y \
    build-essential flex bison libssl-dev libelf-dev \
    libncurses-dev bc wget xz-utils rsync file \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY build.sh /usr/local/bin/build.sh
RUN chmod +x /usr/local/bin/build.sh

ENTRYPOINT ["/usr/local/bin/build.sh"]
