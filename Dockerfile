# syntax=docker/dockerfile:1
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    SAFEOPEN_USER=safeuser \
    SAFEOPEN_HOME=/home/safeuser

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        software-properties-common \
        gosu \
        xvfb \
        xauth \
        x11-apps \
        tigervnc-standalone-server \
        tigervnc-tools \
        xfce4 \
        clamav \
        iptables \
        tini \
    && add-apt-repository -y ppa:canonical-chromium-builds/stage \
    && apt-get update \
    && apt-get install -y --no-install-recommends chromium-browser \
    && apt-get purge -y software-properties-common \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash "$SAFEOPEN_USER" \
    && mkdir -p /safeopen/input \
    && chown -R "$SAFEOPEN_USER:$SAFEOPEN_USER" /safeopen

COPY config /opt/safeopen/config
COPY scripts /opt/safeopen/scripts

RUN chmod +x /opt/safeopen/scripts/*.sh \
    && chmod +x /opt/safeopen/config/network/lockdown.sh

WORKDIR /home/safeuser

ENTRYPOINT ["/opt/safeopen/scripts/entrypoint.sh"]
