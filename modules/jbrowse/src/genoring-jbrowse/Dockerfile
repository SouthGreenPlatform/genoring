# Compile with:
# docker build -t genoring-jbrowse .

FROM nginx

ARG DEBIAN_FRONTEND=noninteractive
ARG JBROWSE_VERSION=1.16.11
ARG GFF3SORT_VERSION=1.0.0

ENV JBROWSE=/opt/jbrowse/
ENV JBROWSE_SAMPLE_DATA=/opt/jbrowse/sample_data/
ENV JBROWSE_DATA=/data/jbrowse/
ENV DATA_DIR=/data/

RUN apt-get -qq update --fix-missing \
    && apt-get --no-install-recommends -y install \
      git \
      build-essential \
      zlib1g-dev \
      libxml2-dev \
      libexpat-dev \
      libpq-dev \
      unzip \
      npm \
      samtools \
      tabix \
      genometools \
      perl-doc \
      fcgiwrap \
      socat

# GFF3sort
RUN curl -L -O https://github.com/billzt/gff3sort/archive/refs/tags/v${GFF3SORT_VERSION}.zip \
    && unzip v${GFF3SORT_VERSION}.zip \
    && rm v${GFF3SORT_VERSION}.zip\
    && mv gff3sort-${GFF3SORT_VERSION} /opt/gff3sort

# JBrowse
RUN curl -L -O https://github.com/GMOD/jbrowse/releases/download/${JBROWSE_VERSION}-release/JBrowse-${JBROWSE_VERSION}.zip \
    && unzip JBrowse-${JBROWSE_VERSION}.zip \
    && rm JBrowse-${JBROWSE_VERSION}.zip \
    && mv JBrowse-${JBROWSE_VERSION} ${JBROWSE}

# RUN mkdir -p ${JBROWSE} && git clone --recursive https://github.com/gmod/jbrowse ${JBROWSE} \
#     && cd ${JBROWSE} \
#     && git checkout ${JBROWSE_VERSION}-release

WORKDIR ${JBROWSE}
RUN ./setup.sh

RUN ./bin/cpanm --force JSON Hash::Merge PerlIO::gzip Devel::Size \
    Heap::Simple Heap::Simple::XS List::MoreUtils Exception::Class Test::Warn Bio::Perl \
    Bio::DB::SeqFeature::Store File::Next Bio::DB::Das::Chado && \
    rm -rf /root/.cpan/ && \
    perl Makefile.PL && make && make install

VOLUME /data/jbrowse/
COPY docker-entrypoint.sh /
COPY res/jbrowse-cgi /opt/jbrowse-cgi
COPY res/jbrowse-nginx.conf /etc/nginx/conf.d/default.conf
RUN /usr/bin/chmod 777 /docker-entrypoint.sh /opt/jbrowse-cgi/*

# Health check: test fcgiwrap socket listener.
HEALTHCHECK --interval=30s --timeout=3s \
  CMD socat -u OPEN:/dev/null UNIX-CONNECT:/var/run/fcgiwrap.socket || exit 1

CMD ["/docker-entrypoint.sh"]
