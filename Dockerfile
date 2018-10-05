FROM huggla/alpine-official:20181005-edge as alpine

ARG PG_MAJOR="10"
ARG PG_VERSION="10.5"
ARG BUILDDEPS="bison coreutils dpkg-dev dpkg flex gcc libc-dev libedit-dev libxml2-dev libxslt-dev make libressl-dev perl-utils perl-ipc-run util-linux-dev zlib-dev openldap-dev"
ARG DESTDIR="/apps/postgresql"

RUN downloadDir="$(mktemp -d)" \
 && wget -O $downloadDir/postgresql.tar.bz2 "http://ftp.postgresql.org/pub/source/v$PG_VERSION/postgresql-$PG_VERSION.tar.bz2" \
 && buildDir="$(mktemp -d)" \
 && tar -xvp -f $downloadDir/postgresql.tar.bz2 -C $buildDir --strip-components 1 \
 && rm -rf $downloadDir \
 && sed -i 's|#define DEFAULT_PGSOCKET_DIR  "/tmp"|#define DEFAULT_PGSOCKET_DIR  "/var/run/postgresql"|g' "$buildDir/src/include/pg_config_manual.h" \
 && wget -O "$buildDir/config/config.guess" 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess' \
 && wget -O "$buildDir/config/config.sub" 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub' \
 && apk --no-cache add $BUILDDEPS \
 && mkdir -p /usr/local/include \
 && cd "$buildDir" \
 && ./configure --build="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" --enable-integer-datetimes --enable-thread-safety --enable-tap-tests --disable-rpath --with-uuid=e2fs --with-gnu-ld --with-pgport=5432 --prefix=/usr/local --with-includes=/usr/local/include --with-libraries=/usr/local/lib --with-openssl --with-libxml --with-libxslt --with-ldap \
 && make -j "$(nproc)" world \
 && make install-world \
 && mkdir -p $DESTDIR $DESTDIR-dev \
 && make -C contrib install \
 && runDeps="$(scanelf --needed --nobanner --format '%n#p' --recursive /usr/local | tr ',' '\n' | sort -u | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' )" \
 && echo "$runDeps" > /apps/RUNDEPS-postgresql \
 && apk --no-cache add $runDeps \
 && apk --no-cache --purge del $BUILDDEPS $runDeps \
 && cd / \
 && rm -rf "$buildDir" $DESTDIR/usr/local/share/doc $DESTDIR/usr/local/share/man \
 && find $DESTDIR/usr/local -name '*.a' -delete

FROM scratch as image

COPY --from=alpine /apps /
