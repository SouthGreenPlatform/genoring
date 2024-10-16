# Compile with:
# docker build -t genoring-jbrowse .

# FROM node:22-bookworm
# 
# LABEL net.genoring.image.authors="v.guignon@cgiar.org"
# 
# USER root
# 
# WORKDIR /
# 
# # Install dependencies.
# RUN apt-get update && apt-get install -y --no-install-recommends samtools tabix
# 
# # Install JBrowse.
# RUN mkdir jbrowse \
#   && cd jbrowse \
#   && wget https://github.com/GMOD/jbrowse/releases/download/1.16.11-release/JBrowse-1.16.11-desktop-linux-x64.zip \
#   && unzip JBrowse-1.16.11-desktop-linux-x64.zip \
#   && rm JBrowse-1.16.11-desktop-linux-x64.zip
# 
# WORKDIR /jbrowse/JBrowse-1.16.11-desktop-linux-x64/resources/app
# 
# EXPOSE 8080
# 
# CMD npx serve -l tcp://0.0.0.0:8080 /jbrowse/JBrowse-1.16.11-desktop-linux-x64/resources/app

FROM nginx
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -qq update --fix-missing
RUN apt-get --no-install-recommends -y install git build-essential zlib1g-dev libxml2-dev libexpat-dev postgresql-client libpq-dev npm

RUN mkdir -p /jbrowse/ && git clone --recursive https://github.com/gmod/jbrowse /jbrowse/ && \
    cd /jbrowse/
#    && \
#    git checkout 1.12.3-release

WORKDIR /jbrowse/
RUN ./setup.sh && \
    ./bin/cpanm --force JSON Hash::Merge PerlIO::gzip Devel::Size \
    Heap::Simple Heap::Simple::XS List::MoreUtils Exception::Class Test::Warn Bio::Perl \
    Bio::DB::SeqFeature::Store File::Next Bio::DB::Das::Chado && \
    rm -rf /root/.cpan/

RUN perl Makefile.PL && make && make install
RUN rm -rf /usr/share/nginx/html && ln -s /jbrowse/ /usr/share/nginx/html

VOLUME /data
COPY docker-entrypoint.sh /
RUN /usr/bin/chmod 777 /docker-entrypoint.sh
CMD ["/docker-entrypoint.sh"]