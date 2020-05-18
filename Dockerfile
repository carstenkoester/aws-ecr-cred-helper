# FIXME - Will want to update this later. At the time of writing, aws-cli was readily available
# as a package (https://pkgs.alpinelinux.org/package/edge/community/x86/aws-cli) for edge repo
# only.
FROM alpine:edge

ARG KUBECTL_VERSION=v1.18.2
ARG USERNAME=helper
ARG UID=1000
ARG GID=1000

RUN apk add --no-cache --virtual .build-deps curl \
 && apk add --no-cache aws-cli bash \
 && curl -LO https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
 && chmod 755 kubectl \
 && mv kubectl /usr/local/bin/ \
 && apk del .build-deps \
 && adduser -u ${UID} -D -H -s /sbin/nologin ${USERNAME}

COPY entrypoint.sh /

USER ${USERNAME}
ENTRYPOINT ["/entrypoint.sh"]
