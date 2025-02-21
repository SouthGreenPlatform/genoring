# Compile with:
# docker build -t genoring-biotools .
FROM httpd

# Arguments.
ARG DEBIAN_FRONTEND=noninteractive
ARG DIAMOND_VERSION=2.1.11
ARG GFF3SORT_VERSION=1.0.0
ARG GET_HOMOLOGUES_EST_VERSION=3.7.2
ARG GET_HOMOLOGUES_EST_DATE=20241114
ARG ORTHOMCL_VERSION=2.0.9

RUN apt-get -qq update --fix-missing \
    && apt-get --no-install-recommends -y install \
      man \
      debconf-utils \
      libcap2-bin \
      lsb-release \
      gnupg \
      vim \
      nano \
      tree \
      dos2unix \
      zip \
      git \
      build-essential \
      unzip \
      rsync \
      npm \
      perl-doc \
      libcgi-pm-perl \
      libbio-perl-perl \
      libdbi-perl \
      libdbd-mysql-perl \
      libdbd-pg-perl \
      samtools \
      tabix \
      genometools \
      vcftools \
      phylip \
      mafft \
      bowtie2 \
      phyml \
      ncbi-blast+ \
      hmmer hmmer-doc \
      mcl \
      busco \
      graphviz graphviz-doc \
      ftp \
      wget \
      curl
# @todo See if could be usefull: ruby-full rubygems nodejs autoconf shoot t-cofee/3dcoffee

# # MySQL (for OrthoMCL). Requires DEBIAN_FRONTEND=noninteractive for dpkg.
# RUN wget https://dev.mysql.com/get/mysql-apt-config_0.8.33-1_all.deb -O /tmp/mysql-apt-config_0.8.33-1_all.deb \
#     && printf "mysql-apt-config mysql-apt-config/select-server select mysql-8.4-lts\n" | debconf-set-selections \
#     && printf "mysql-apt-config mysql-apt-config/select-product select Ok\n" | debconf-set-selections \
#     && dpkg -i /tmp/mysql-apt-config_0.8.33-1_all.deb \
#     && rm /tmp/mysql-apt-config_0.8.33-1_all.deb \
#     && apt-get update \
#     && printf "\n" | apt-get install -y mysql-server \
#     && systemctl status mysql

# Perl libs.
RUN printf "y\n" | cpan App::cpanminus \
    && cpanm -n Algorithm::Combinatorics Parallel::ForkManager Set::Scalar \
         Exception::Class Test::Most Test::Warn Test::Exception Test::Deep \
         Sort::Naturally Sort::Topological Moose Text::Table JSON SVG YAML YAML::Tiny

# GFF3sort
RUN curl -L -O https://github.com/billzt/gff3sort/archive/refs/tags/v${GFF3SORT_VERSION}.zip \
    && unzip v${GFF3SORT_VERSION}.zip \
    && rm v${GFF3SORT_VERSION}.zip \
    && mv gff3sort-${GFF3SORT_VERSION} /opt/gff3sort \
    && ln -s /opt/gff3sort/gff3sort.pl /usr/bin/gff3sort.pl \
    && ln -s /opt/gff3sort/check-disorder.pl /usr/bin/check-disorder.pl

# diamond
RUN curl -L -O http://github.com/bbuchfink/diamond/releases/download/v${DIAMOND_VERSION}/diamond-linux64.tar.gz \
    && mkdir -p /opt/diamond \
    && tar zxvf diamond-linux64.tar.gz --directory /opt/diamond/ \
    && rm diamond-linux64.tar.gz \
    && ln -s /opt/diamond/diamond /usr/bin/diamond

# get_homologes-est
RUN curl -L -O https://github.com/eead-csic-compbio/get_homologues/releases/download/v${GET_HOMOLOGUES_EST_VERSION}/get_homologues-x86_64-${GET_HOMOLOGUES_EST_DATE}.tgz \
    && tar zxvf get_homologues-x86_64-${GET_HOMOLOGUES_EST_DATE}.tgz --directory /opt \
    && rm get_homologues-x86_64-${GET_HOMOLOGUES_EST_DATE}.tgz \
    && mv /opt/get_homologues-x86_64-${GET_HOMOLOGUES_EST_DATE} /opt/get_homologues

# # OrthoMCL
# https://orthomcl.org/common/downloads/software/v2.0/UserGuide.txt
# https://github.com/apetkau/orthomcl-pipeline/blob/master/INSTALL.md
# https://github.com/genomeannotation/OrthoMCL-docker/blob/master/Dockerfile
# RUN curl -L -O http://www.orthomcl.org/common/downloads/software/v2.0/orthomclSoftware-v${ORTHOMCL_VERSION}.tar.gz \
#    && tar -xzvf orthomclSoftware-v${ORTHOMCL_VERSION}.tar.gz --directory /opt \
#    && rm orthomclSoftware-v${ORTHOMCL_VERSION}.tar.gz \
#    && mv /opt/orthomclSoftware-v${ORTHOMCL_VERSION} /opt/orthomcl
# ENV PATH $PATH:/opt/orthomcl/bin

COPY res/biotools /opt/biotools
COPY res/biotools-httpd.conf /usr/local/apache2/conf/httpd.conf

# Adjust file permissions.
RUN /usr/bin/chmod uog+x /opt/biotools/cgi-bin/*

# Secure environment by using www-data.
RUN chown -hR www-data:www-data /usr/local/apache2/
RUN setcap 'cap_net_bind_service=+ep' /usr/local/apache2/bin/httpd
RUN getcap /usr/local/apache2/bin/httpd

HEALTHCHECK --interval=60s --timeout=30s CMD nc -zv localhost 80 || exit 1

# # Health check: test mysql socket listener.
# HEALTHCHECK --interval=30s --timeout=3s \
#   CMD socat -u OPEN:/dev/null UNIX-CONNECT:/var/run/mysql.socket || exit 1

USER www-data
WORKDIR /opt/biotools/
