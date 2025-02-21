# Compile with:
# docker build -t genoring-jbrowse .

FROM httpd

# Arguments.
ARG DEBIAN_FRONTEND=noninteractive
ARG JBROWSE_VERSION=1.16.11

# Environment.
ENV JBROWSE=/opt/jbrowse/
ENV JBROWSE_SAMPLE_DATA=/opt/jbrowse/sample_data/
ENV JBROWSE_DATA=/data/jbrowse/

RUN apt-get -qq update --fix-missing \
    && apt-get --no-install-recommends -y install \
      libcap2-bin \
      build-essential \
      git \
      zlib1g-dev \
      libxml2-dev \
      libexpat-dev \
      libpq-dev \
      unzip \
      npm \
      curl \
      perl-doc \
      libcgi-pm-perl \
      libbio-perl-perl \
      libdbi-perl \
      libdbd-pg-perl

# JBrowse
RUN curl -L -O https://github.com/GMOD/jbrowse/releases/download/${JBROWSE_VERSION}-release/JBrowse-${JBROWSE_VERSION}.zip \
    && unzip JBrowse-${JBROWSE_VERSION}.zip \
    && rm JBrowse-${JBROWSE_VERSION}.zip \
    && mkdir -p $(dirname ${JBROWSE}) \
    && mv JBrowse-${JBROWSE_VERSION}  ${JBROWSE}

WORKDIR ${JBROWSE}

RUN ./setup.sh

RUN ./bin/cpanm --force JSON Hash::Merge PerlIO::gzip Devel::Size \
    Heap::Simple Heap::Simple::XS List::MoreUtils Exception::Class Test::Warn \
    Bio::DB::SeqFeature::Store File::Next Bio::DB::Das::Chado && \
    rm -rf /root/.cpan/ && \
    perl Makefile.PL && make && make install

# Prepare file system.
COPY res/jbrowse-httpd.conf /usr/local/apache2/conf/httpd.conf
COPY res/jbrowse-cgi /opt/jbrowse-cgi
RUN /usr/bin/chmod uog+x /opt/jbrowse-cgi/*

# Secure environment by using www-data.
RUN chown -hR www-data:www-data /usr/local/apache2/
RUN setcap 'cap_net_bind_service=+ep' /usr/local/apache2/bin/httpd
RUN getcap /usr/local/apache2/bin/httpd

HEALTHCHECK --interval=60s --timeout=30s CMD nc -zv localhost 80 || exit 1

USER www-data
