FROM debian:12
RUN apt-get update ; apt-get -y install git sudo
WORKDIR /nanodesk
ENTRYPOINT /nanodesk/makeanything.sh
