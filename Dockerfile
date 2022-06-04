# Specifying versions directly in the Dockerfile lets tools parse
# them, but then the versions must be repeated for the labels, which
# means the two can drift out of sync. When both are controlled
# externally instead, there is always a single source of truth to
# update.

ARG ARGOCD_VERSION
ARG GO_VERSION
ARG KSOPS_VERSION
ARG CURL_VERSION

FROM golang:$GO_VERSION AS common

RUN apk add -q --no-cache git=2.34.2-r0 musl-dev=1.2.2-r7 gcc=10.3.1_git20211027-r0

FROM common AS jb-builder

ARG JSONNET_BUNDLER_COMMIT

RUN go install -ldflags="-extldflags=-static -linkmode=external -X main.Version=$JSONNET_BUNDLER_COMMIT" github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@$JSONNET_BUNDLER_COMMIT

FROM common AS go-jsonnet-builder

ARG GOJSONNET_VERSION

RUN go install -ldflags='-extldflags=-static -linkmode=external' github.com/google/go-jsonnet/cmd/jsonnet@$GOJSONNET_VERSION

FROM common AS go-jsontoyaml-builder

ARG GOJSONTOYAML_VERSION

RUN go install -ldflags='-extldflags=-static -linkmode=external' github.com/brancz/gojsontoyaml@$GOJSONTOYAML_VERSION

FROM viaductoss/ksops:$KSOPS_VERSION AS ksops-builder

FROM curlimages/curl:$CURL_VERSION AS age

ARG AGE_VERSION

WORKDIR /tmp/age

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN curl -sSL "https://github.com/FiloSottile/age/releases/download/$AGE_VERSION/age-${AGE_VERSION}-linux-amd64.tar.gz" | tar xzvf -

FROM quay.io/argoproj/argocd:$ARGOCD_VERSION

ARG HELM_SECRETS_VERSION

RUN helm plugin install https://github.com/jkroepke/helm-secrets --version $HELM_SECRETS_VERSION

# Switch to root for the ability to perform install
USER root

# Set the kustomize home directory
ENV XDG_CONFIG_HOME=$HOME/.config
ENV KUSTOMIZE_PLUGIN_PATH=$XDG_CONFIG_HOME/kustomize/plugin/

ARG PKG_NAME=ksops

COPY --from=jb-builder /go/bin/jb /usr/local/bin/jb

COPY --from=go-jsonnet-builder /go/bin/jsonnet /usr/local/bin/jsonnet

COPY --from=go-jsontoyaml-builder /go/bin/gojsontoyaml /usr/local/bin/gojsontoyaml

# Override the default kustomize executable with the Go built version
COPY --from=ksops-builder /go/bin/kustomize /usr/local/bin/kustomize

COPY --from=age /tmp/age/age /usr/local/bin/

# Switch back to non-root user
USER 999

# Copy the plugin to kustomize plugin path
COPY --from=ksops-builder /go/src/github.com/viaduct-ai/kustomize-sops/* $KUSTOMIZE_PLUGIN_PATH/viaduct.ai/v1/${PKG_NAME}/

ENV HELM_SECRETS_SOPS_PATH=$KUSTOMIZE_PLUGIN_PATH/viaduct.ai/v1/${PKG_NAME}/sops
