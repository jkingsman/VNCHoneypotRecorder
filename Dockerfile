FROM debian:12 AS vnc-base

RUN apt update && apt upgrade -y

RUN apt install -y \
    xvfb \
    x11-utils \
    dbus-x11 \
    xfce4 \
    xfce4-goodies \
    x11vnc \
    firefox-esr \
    net-tools \
    supervisor

# power manager crashes in containers
# removing this causes some xfce4 warnings in the logs (`Failed to execute child process "/usr/bin/pm-is-supported" (No such file or directory)`)
# but is better than a locked interface and then a panel crash popup on the desktop
RUN apt remove -y xfce4-power-manager

# bobby runs things around here
RUN useradd -m -s /bin/bash -u 1000 bobby && \
    usermod -aG audio,video bobby

# bobby owns things around here
RUN mkdir -p /var/log/supervisor && \
    mkdir -p /var/run && \
    mkdir -p /etc/supervisor/conf.d/ && \
    mkdir -p /home/bobby/.config && \
    mkdir -p /home/bobby/.cache && \
    chown -R bobby:bobby /home/bobby && \
    chown -R bobby:bobby /var/log/supervisor && \
    chown -R bobby:bobby /var/run && \
    chmod 755 /var/log/supervisor && \
    chmod 1777 /tmp

COPY honeypot_contents/supervisord-base.conf /etc/supervisor/conf.d/supervisord.conf

# bobby!
USER bobby
WORKDIR /home/bobby

EXPOSE 5900
ENV X11VNC_CREATE_GEOM=1024x768x16
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

####
# Eveything above here is a pretty normal VNC container with some bad security like 777 /tmp
####

# stage 2: gimme some honey!
FROM vnc-base AS honeypot

USER root
RUN apt install -y ffmpeg

# recordings need homes too
RUN mkdir -p /tmp/recordings && \
    chown -R bobby:bobby /tmp/recordings && \
    chmod 755 /tmp/recordings

# copy and obfuscate the recording script
COPY honeypot_contents/vnc-recording-monitor.sh /usr/local/bin/systemd-monitor
RUN chmod +x /usr/local/bin/systemd-monitor

# rename ffmpeg to something vaguely stealthier
RUN cp /usr/bin/ffmpeg /usr/local/bin/systemd-helper && \
    chmod +x /usr/local/bin/systemd-helper

# append recording script config to supervisord
COPY honeypot_contents/supervisord-recording.conf /tmp/supervisord-recording.conf
RUN cat /tmp/supervisord-recording.conf >> /etc/supervisor/conf.d/supervisord.conf && \
    rm /tmp/supervisord-recording.conf

# bobby! again!
USER bobby
WORKDIR /home/bobby


FROM honeypot AS honeypot-with-utils

USER root

# one of the attackers swore at me because I was missing wget and sudo heehee
RUN apt update && apt install -y \
    wget \
    curl \
    git \
    vim \
    build-essential \
    gcc \
    g++ \
    make \
    python3 \
    python3-pip \
    perl \
    ruby \
    openssh-client \
    dnsutils \
    htop \
    lsof \
    file \
    zip \
    unzip \
    tar \
    gzip \
    bzip2 \
    p7zip-full \
    ca-certificates \
    gnupg \
    apt-transport-https

# tfake nvidia-smi with 2x H100s
COPY honeypot_contents/nvidia-smi /usr/local/bin/nvidia-smi
RUN chmod +x /usr/local/bin/nvidia-smi

# fake sudo
COPY honeypot_contents/sudo /usr/local/bin/sudo
RUN chmod +x /usr/local/bin/sudo

# Switch back to bobby
USER bobby
WORKDIR /home/bobby
