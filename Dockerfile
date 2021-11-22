ARG ARGOCD_VERSION

FROM golang:1.17.0-alpine AS common

LABEL go.version="1.17.0"

RUN apk add -q --no-cache git=2.32.0-r0 musl-dev=1.2.2-r3 gcc=10.3.1_git20210424-r2

FROM common AS jb-builder

ARG JSONNET_BUNDLER_COMMIT

RUN go install -ldflags='-extldflags=-static -linkmode=external' github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@$JSONNET_BUNDLER_COMMIT

FROM common AS go-jsonnet-builder

ARG GOJSONNET_VERSION

RUN go install -ldflags='-extldflags=-static -linkmode=external' github.com/google/go-jsonnet/cmd/jsonnet@$GOJSONNET_VERSION

FROM common AS go-jsontoyaml-builder

ARG GOJSONTOYAML_VERSION

RUN go install -ldflags='-extldflags=-static -linkmode=external' github.com/brancz/gojsontoyaml@$GOJSONTOYAML_VERSION

FROM viaductoss/ksops:v3.0.0 AS ksops-builder

LABEL tools.ksops.version="v3.0.0"

FROM curlimages/curl:7.80.0 AS age

WORKDIR /tmp/age

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN curl -sSL 'https://github.com/FiloSottile/age/releases/download/v1.0.0/age-v1.0.0-linux-amd64.tar.gz' | tar xzvf -

FROM quay.io/argoproj/argocd:$ARGOCD_VERSION

ARG HELM_SECRETS_VERSION

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

RUN helm plugin install https://github.com/jkroepke/helm-secrets --version $HELM_SECRETS_VERSION
