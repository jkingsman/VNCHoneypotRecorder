FROM debian:12

USER root
RUN apt update && apt upgrade -y

RUN apt install -y \
    xvfb \
    x11-utils \
    dbus-x11 \
    xfce4 \
    xfce4-goodies \
    x11vnc \
    firefox-esr \
    ffmpeg \
    net-tools \
    supervisor

# power manager crashes in containers
RUN apt remove -y xfce4-power-manager

RUN mkdir -p /recordings

RUN mkdir -p /etc/supervisor/conf.d/
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# minimal obfuscation for the recording script
COPY vnc-recording-monitor.sh /usr/local/bin/systemd-monitor
RUN chmod +x /usr/local/bin/systemd-monitor

EXPOSE 5900
ENV X11VNC_CREATE_GEOM=1024x768x16
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
