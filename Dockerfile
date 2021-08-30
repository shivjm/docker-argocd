ARG ARGOCD_VERSION
ARG HELM_SECRETS_VERSION
ARG KSOPS_VERSION
ARG GO_VERSION
ARG JSONNET_BUNDLER_COMMIT

FROM golang:$GO_VERSION-alpine AS common

RUN apk add -q --no-cache git musl-dev gcc

FROM common AS jb-builder

RUN mkdir /jsonnet-bundler && \
    cd /jsonnet-bundler && \
    git init --quiet && \
    git remote add origin https://github.com/jsonnet-bundler/jsonnet-bundler.git && \
    git fetch -n --depth 1 origin $JSONNET_BUNDLER_COMMIT && \
    git reset --hard FETCH_HEAD && \
    go build -ldflags='-extldflags=-static -linkmode=external' -o jb /jsonnet-bundler/cmd/jb

FROM common AS go-jsonnet-builder

ARG GOJSONNET_VERSION

RUN go install -ldflags='-extldflags=-static -linkmode=external' github.com/google/go-jsonnet/cmd/jsonnet@$GOJSONNET_VERSION

FROM common AS go-jsontoyaml-builder

ARG GOJSONTOYAML_VERSION

RUN go install -ldflags='-extldflags=-static -linkmode=external' github.com/brancz/gojsontoyaml@$GOJSONTOYAML_VERSION

FROM viaductoss/ksops:$KSOPS_VERSION AS ksops-builder

FROM quay.io/argoproj/argocd:$ARGOCD_VERSION

ARG HELM_SECRETS_VERSION

# Switch to root for the ability to perform install
USER root

# Set the kustomize home directory
ENV XDG_CONFIG_HOME=$HOME/.config
ENV KUSTOMIZE_PLUGIN_PATH=$XDG_CONFIG_HOME/kustomize/plugin/

ARG PKG_NAME=ksops

COPY --from=jb-builder /jsonnet-bundler/jb /usr/local/bin/jb

COPY --from=go-jsonnet-builder /go/bin/jsonnet /usr/local/bin/jsonnet

COPY --from=go-jsontoyaml-builder /go/bin/gojsontoyaml /usr/local/bin/gojsontoyaml

# Override the default kustomize executable with the Go built version
COPY --from=ksops-builder /go/bin/kustomize /usr/local/bin/kustomize

# Switch back to non-root user
USER 999

# Copy the plugin to kustomize plugin path
COPY --from=ksops-builder /go/src/github.com/viaduct-ai/kustomize-sops/* $KUSTOMIZE_PLUGIN_PATH/viaduct.ai/v1/${PKG_NAME}/

ENV HELM_SECRETS_SOPS_PATH=$KUSTOMIZE_PLUGIN_PATH/viaduct.ai/v1/${PKG_NAME}/sops

RUN helm plugin install https://github.com/jkroepke/helm-secrets --version $HELM_SECRETS_VERSION
