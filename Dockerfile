FROM ubuntu:xenial

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential \
        cpanminus \
        libssl-dev \
        libxml2-dev \
        openssl \
        zlib1g-dev

COPY cpanfile /tmp/
RUN cpanm --installdeps -q /tmp

WORKDIR /twitrssme
COPY lib /twitrssme/lib/
COPY bin /twitrssme/bin/

ENV PERL5LIB=/twitrssme/lib \
    MOJO_MODE=production

CMD [ "/twitrssme/bin/twitrssmojo", "prefork", \
        "--listen", "http://*:80", \
        "--workers", "1" ]

EXPOSE 80
