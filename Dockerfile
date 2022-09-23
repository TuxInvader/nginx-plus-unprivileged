ARG IMAGE=debian:buster-slim
FROM $IMAGE

LABEL maintainer="NGINX Docker Maintainers <docker-maint@nginx.com>"

ENV NGINX_VERSION   27
ENV NJS_VERSION     0.7.4
ENV PKG_RELEASE     1~buster
ENV NGINX_NMS_HOST  ""
ENV NGINX_NAP_PKGS  "app-protect app-protect-attack-signatures app-protect-threat-campaigns"

ARG UID=101
ARG GID=101

RUN --mount=type=secret,id=nginx-crt,dst=nginx-repo.crt \
    --mount=type=secret,id=nginx-key,dst=nginx-repo.key \
    set -x \
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup --system --gid $GID nginx || true \
    && adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false --uid $UID nginx || true \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y apt-transport-https wget gnupg2 ca-certificates lsb-release sudo procps curl; \
    if [ -n "${NGINX_NAP_PKGS}" ] ; then \
      curl https://cs.nginx.com/static/keys/nginx_signing.key | apt-key add - ; \
      curl https://cs.nginx.com/static/keys/app-protect-security-updates.key | apt-key add - ; \
    fi; \
    NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
    found=''; \
    for server in \
        hkp://keyserver.ubuntu.com:80 \
        pgp.mit.edu \
    ; do \
        echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
        apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \


# Install the latest release of NGINX Plus and/or NGINX Plus modules
# Uncomment individual modules if necessary
# Use versioned packages over defaults to specify a release
    nginxPackages=" \
        nginx-plus \
        nginx-plus=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-plus-module-xslt=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-plus-module-geoip=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-plus-module-image-filter=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-plus-module-njs=${NGINX_VERSION}+${NJS_VERSION}-${PKG_RELEASE} \
        ${NGINX_NAP_PKGS} \
    " \
    && echo "Acquire::https::pkgs.nginx.com::Verify-Peer \"true\";" > /etc/apt/apt.conf.d/90nginx \
    && echo "Acquire::https::pkgs.nginx.com::Verify-Host \"true\";" >> /etc/apt/apt.conf.d/90nginx \
    && echo "Acquire::https::pkgs.nginx.com::SslCert     \"/etc/ssl/nginx/nginx-repo.crt\";" >> /etc/apt/apt.conf.d/90nginx \
    && echo "Acquire::https::pkgs.nginx.com::SslKey      \"/etc/ssl/nginx/nginx-repo.key\";" >> /etc/apt/apt.conf.d/90nginx \
    && printf "deb https://pkgs.nginx.com/plus/debian `lsb_release -cs` nginx-plus\n" > /etc/apt/sources.list.d/nginx-plus.list \
    && mkdir -p /etc/ssl/nginx \
    && cat nginx-repo.crt > /etc/ssl/nginx/nginx-repo.crt \
    && cat nginx-repo.key > /etc/ssl/nginx/nginx-repo.key; \
    if [ -n "${NGINX_NAP_PKGS}" ] ; then \
      printf "deb https://pkgs.nginx.com/app-protect/debian `lsb_release -cs` nginx-plus\n" > /etc/apt/sources.list.d/nginx-app-protect.list; \
      printf "deb https://pkgs.nginx.com/app-protect-security-updates/debian `lsb_release -cs` nginx-plus\n" > /etc/apt/sources.list.d/app-protect-security-updates.list; \
      mkdir -p /etc/nginx/waf/nac-policies /etc/nginx/waf/nac-logconfs /etc/nginx/waf/nac-usersigs /var/log/app_protect /opt/app_protect; \
    fi; \
    apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y \
                        $nginxPackages \
                        curl \
                        zlib1g libbz2-1.0 \
                        gettext-base ;\

# Install the NIM/NMS agent if ENV is set.
    if [ -n "${NGINX_NMS_HOST}" ] ; then \
      curl -k -o /tmp/agent-installer.sh https://${NGINX_NMS_HOST}/install/nginx-agent \
      && sh /tmp/agent-installer.sh \
      && mkdir -p /var/run/nginx-agent \
      && mkdir -p /var/log/nginx-agent \
      && sudo chown -R $UID:0 /etc/nginx-agent /var/run/nginx-agent /var/log/nginx-agent \
      && SUDO_FORCE_REMOVE=yes apt-get remove --purge --auto-remove -y gnupg2 sudo && rm -rf /var/lib/apt/lists/* ; \
    fi; \

# purge stuff
    apt-get remove --purge -y lsb-release \
    && apt-get remove --purge --auto-remove -y && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx-plus.list \
    && rm -rf /etc/apt/apt.conf.d/90nginx /etc/ssl/nginx \

# Forward request logs to Docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \


# create a docker-entrypoint.d directory
    && mkdir /docker-entrypoint.d

# implement changes required to run NGINX as an unprivileged user
RUN sed -i -r 's,listen\s+80,listen       8080,' /etc/nginx/conf.d/default.conf \
    && sed -i '/user  nginx;/d' /etc/nginx/nginx.conf \
    && sed -i 's,/var/run/nginx.pid,/tmp/nginx.pid,' /etc/nginx/nginx.conf \
    && sed -i "/^http {/a \    proxy_temp_path /tmp/proxy_temp;\n    client_body_temp_path /tmp/client_temp;\n    fastcgi_temp_path /tmp/fastcgi_temp;\n    uwsgi_temp_path /tmp/uwsgi_temp;\n    scgi_temp_path /tmp/scgi_temp;\n" /etc/nginx/nginx.conf \
# nginx user must own the cache and etc directory to write cache and tweak the nginx config
    && chown -R $UID:0 /var/cache/nginx \
    && chmod -R g+w /var/cache/nginx \
    && chown -R $UID:0 /etc/nginx \
    && chmod -R g+w /etc/nginx ;\
    if [ -n "${NGINX_NAP_PKGS}" ] ; then \
      chown -R $UID:0 /etc/app_protect /usr/share/ts /var/log/app_protect/ /opt/app_protect/ /var/log/nginx/ ; \
      touch /etc/nginx/waf/nac-usersigs/index.conf ; \
    fi

COPY docker-entrypoint.sh /
COPY 10-listen-on-ipv6-by-default.sh /docker-entrypoint.d
COPY 20-envsubst-on-templates.sh /docker-entrypoint.d
COPY 30-tune-worker-processes.sh /docker-entrypoint.d
COPY 40-load-nap.sh /docker-entrypoint.d
COPY 41-load-agent.sh /docker-entrypoint.d
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 8080

STOPSIGNAL SIGQUIT

USER $UID

CMD ["nginx", "-g", "daemon off;"]

