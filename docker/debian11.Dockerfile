FROM debian:11

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       sudo systemd systemd-sysv \
       python3 \
    && rm -rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && apt-get clean

RUN rm -f /lib/systemd/system/multi-user.target.wants/getty.target

VOLUME [ "/sys/fs/cgroup" ]

CMD ["/lib/systemd/systemd"]
