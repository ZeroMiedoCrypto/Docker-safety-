# Dockerfile for safeopen disposable environment
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        software-properties-common \
        gnupg \
        wget \
        xz-utils \
        chromium-browser \
        xvfb \
        fluxbox \
        tigervnc-standalone-server \
        tigervnc-common \
        clamav \
        clamav-daemon \
        iptables \
        sudo \
        x11-xserver-utils \
        dbus-x11 \
        fonts-liberation \
        locales \
        procps \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/chromium-browser /usr/bin/chromium || true
RUN sed -i 's|^#\?DatabaseMirror .*|DatabaseMirror https://database.clamav.net|' /etc/clamav/freshclam.conf \
    && sed -i 's|^#\?NotifyClamd .*|NotifyClamd false|' /etc/clamav/freshclam.conf

RUN useradd --create-home --shell /bin/bash --gid users safeuser \
    && usermod -aG sudo safeuser \
    && echo 'safeuser ALL=(ALL) NOPASSWD: /usr/sbin/iptables, /usr/bin/clamdscan, /usr/bin/clamscan' >> /etc/sudoers.d/safeuser \
    && locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

COPY scripts/container_entry.sh /usr/local/bin/container_entry.sh
RUN chmod +x /usr/local/bin/container_entry.sh

USER root
ENTRYPOINT ["/usr/local/bin/container_entry.sh"]
