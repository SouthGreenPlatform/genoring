# Compile with:
#   docker build -t genoring-db .
FROM postgis/postgis:18-3.6

LABEL net.genoring.image.authors="v.guignon@cgiar.org"
LABEL description="PostgreSQL 18 with PostGIS and pgvector"

# Adds PgVector (from https://hub.docker.com/r/pgvector/pgvector).
ADD https://github.com/pgvector/pgvector/archive/refs/tags/v0.8.4.tar.gz /tmp
RUN mkdir -p /tmp/pgvector \
    && tar -xzf /tmp/v0.8.4.tar.gz -C /tmp/pgvector --strip-components=1 \
    && rm /tmp/v0.8.4.tar.gz

RUN apt-get update \
  && apt-mark hold locales \
  && apt-get install -y --no-install-recommends \
	  build-essential \
		postgresql-server-dev-$PG_MAJOR \
	&& cd /tmp/pgvector \
	&& make clean \
	&& make OPTFLAGS="" \
	&& make install \
	&& mkdir /usr/share/doc/pgvector \
	&& cp LICENSE README.md /usr/share/doc/pgvector \
	&& rm -r /tmp/pgvector \
	&& apt-get remove -y build-essential postgresql-server-dev-$PG_MAJOR \
	&& apt-get autoremove -y \
	&& apt-mark unhold locales \
	&& rm -rf /var/lib/apt/lists/*
