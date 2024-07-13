# Compile with:
# docker build -t genoring-jbrowse2 .

FROM node:22-bookworm

LABEL net.genoring.image.authors="v.guignon@cgiar.org"

USER root

WORKDIR /

# Install dependencies.
RUN apt-get update && apt-get install -y --no-install-recommends samtools tabix

# Install JBrowse 2.
RUN mkdir jbrowse2 \
  && cd jbrowse2 \
  && wget https://github.com/GMOD/jbrowse-components/releases/download/v2.12.3/jbrowse-web-v2.12.3.zip \
  && unzip jbrowse-web-v2.12.3.zip \
  && rm jbrowse-web-v2.12.3.zip

WORKDIR /jbrowse2

EXPOSE 8080

CMD npx serve -l tcp://0.0.0.0:8080 /jbrowse2