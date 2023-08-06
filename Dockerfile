# Copyright Omnistrate, Inc.
# SPDX-License-Identifier: APACHE-2.0

FROM docker.io/bitnami/minideb:bullseye

ARG EXTRA_LOCALES
ARG TARGETARCH
ARG WITH_ALL_LOCALES="no"

LABEL org.opencontainers.image.base.name="docker.io/bitnami/minideb:bullseye" \
      org.opencontainers.image.created="2023-07-14T00:10:07Z" \
      org.opencontainers.image.description="Application packaged by Omnistrate, Inc." \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.ref.name="15.3.0-debian-11-r24" \
      org.opencontainers.image.title="postgresql" \
      org.opencontainers.image.vendor="Omnistrate, Inc." \
      org.opencontainers.image.version="15.3.0"

ENV HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    OS_FLAVOUR="debian-11" \
    OS_NAME="linux"

COPY prebuildfs /
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# Install required system packages and dependencies
RUN install_packages ca-certificates curl libbsd0 libbz2-1.0 libedit2 libffi7 libgcc-s1 libgmp10 libgnutls30 libhogweed6 libicu67 libidn2-0 libldap-2.4-2 liblz4-1 liblzma5 libmd0 libncurses6 libnettle8 libp11-kit0 libpcre3 libreadline8 libsasl2-2 libsqlite3-0 libssl1.1 libstdc++6 libtasn1-6 libtinfo6 libunistring2 libuuid1 libxml2 libxslt1.1 libzstd1 locales procps zlib1g
RUN mkdir -p /tmp/bitnami/pkg/cache/ && cd /tmp/bitnami/pkg/cache/ && \
    COMPONENTS=( \
      "postgresql-15.3.0-6-linux-${OS_ARCH}-debian-11" \
    ) && \
    for COMPONENT in "${COMPONENTS[@]}"; do \
      if [ ! -f "${COMPONENT}.tar.gz" ]; then \
        curl -SsLf "https://downloads.bitnami.com/files/stacksmith/${COMPONENT}.tar.gz" -O ; \
        curl -SsLf "https://downloads.bitnami.com/files/stacksmith/${COMPONENT}.tar.gz.sha256" -O ; \
      fi && \
      sha256sum -c "${COMPONENT}.tar.gz.sha256" && \
      tar -zxf "${COMPONENT}.tar.gz" -C /opt/bitnami --strip-components=2 --no-same-owner --wildcards '*/files' && \
      rm -rf "${COMPONENT}".tar.gz{,.sha256} ; \
    done

ENV PG_CONFIG=/opt/bitnami/postgresql/bin/pg_config

# Setup PG repo and dev tools
RUN apt-get update && apt-get install wget gnupg -y
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
RUN apt-get update && \
		apt-get install -y --no-install-recommends build-essential postgresql-server-dev-15 cmake

# Install pgvector
COPY pgvector /tmp/pgvector
RUN	cd /tmp/pgvector &&  \
		make clean && \
		make OPTFLAGS="" && \
		make install && \
		mkdir /usr/share/doc/pgvector && \
		cp LICENSE README.md /usr/share/doc/pgvector && \
		rm -r /tmp/pgvector

# Install lanterndb
COPY lanterndb /tmp/lanterndb

RUN cd /tmp/lanterndb && mkdir build && cd build && \
  cmake -DUSEARCH_NO_MARCH_NATIVE=ON -DPG_CONFIG=/opt/bitnami/postgresql/bin/pg_config .. && \
  make clean && \
  make install && \
  rm -rf /tmp/lanterndb

# Cleanup
RUN apt-get autoremove --purge -y curl wget gnupg build-essential postgresql-server-dev-15 cmake && \
    apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives
RUN chmod g+rwX /opt/bitnami
RUN localedef -c -f UTF-8 -i en_US en_US.UTF-8
RUN update-locale LANG=C.UTF-8 LC_MESSAGES=POSIX && \
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales
RUN echo 'en_GB.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen
RUN echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen

COPY rootfs /
RUN /opt/bitnami/scripts/postgresql/postunpack.sh
RUN /opt/bitnami/scripts/locales/add-extra-locales.sh
ENV APP_VERSION="15.3.0" \
    BITNAMI_APP_NAME="postgresql" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    NSS_WRAPPER_LIB="/opt/bitnami/common/lib/libnss_wrapper.so" \
    PATH="/opt/bitnami/postgresql/bin:$PATH"

VOLUME [ "/bitnami/postgresql", "/docker-entrypoint-initdb.d", "/docker-entrypoint-preinitdb.d" ]

EXPOSE 5432

USER 1001
ENTRYPOINT [ "/opt/bitnami/scripts/postgresql/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/postgresql/run.sh" ]

