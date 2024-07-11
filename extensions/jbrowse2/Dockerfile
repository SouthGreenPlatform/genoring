# Compile with:
# docker build -t genoring-jbrowse2 .

FROM node:lts-alpine3.13

LABEL org.opencontainers.image.authors="v.guignon@cgiar.org"

USER root

WORKDIR /

RUN mkdir jbrowse2 \
  && cd jbrowse2 \
  && wget https://github.com/GMOD/jbrowse-components/releases/download/v2.12.3/jbrowse-web-v2.12.3.zip \
  && unzip jbrowse-web-v2.12.3.zip \
  && rm jbrowse-web-v2.12.3.zip

COPY ./nginx/jbrowse.conf /etc/nginx/genoring/jbrowse.conf

WORKDIR /jbrowse2

EXPOSE 8080

CMD npx serve -l tcp://0.0.0.0:8080 /jbrowse2