# syntax=docker/dockerfile:1

# FROM alpine
# WORKDIR /home
# RUN apk add --no-cache bash
# RUN apk add build-base

FROM debian
WORKDIR /home
RUN apt-get update
RUN apt-get install -y bash
RUN apt-get install -y build-essential
