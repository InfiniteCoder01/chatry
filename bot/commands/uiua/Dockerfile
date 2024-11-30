# syntax=docker/dockerfile:1

FROM ubuntu

ENV LANG=C.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=C.UTF-8

RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get -y install curl

RUN bash -c "$(curl -fsSL https://raw.github.com/seeker-3/what-the-dock/main/install.bash)"

RUN apt-get -y install \
    unzip \
    libasound2t64

RUN apt-get autoremove
RUN apt-get clean
RUN apt-get autoclean
RUN apt-get -f install

# Install uiua
RUN curl -fsSL -o uiua.zip https://github.com/uiua-lang/uiua/releases/download/0.13.0-dev.2/uiua-bin-x86_64-unknown-linux-gnu.zip
RUN unzip uiua.zip
RUN rm uiua.zip
RUN mkdir -p /usr/local/bin
RUN mv uiua /usr/local/bin/uiua
