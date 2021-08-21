ARG ARGOCD_VERSION
ARG HELM_SECRETS_VERSION
ARG KSOPS_VERSION

FROM viaductoss/ksops:$KSOPS_VERSION as ksops-builder

FROM quay.io/argoproj/argocd:$ARGOCD_VERSION

ARG HELM_SECRETS_VERSION

# Switch to root for the ability to perform install
USER root

# Set the kustomize home directory
ENV XDG_CONFIG_HOME=$HOME/.config
ENV KUSTOMIZE_PLUGIN_PATH=$XDG_CONFIG_HOME/kustomize/plugin/

ARG PKG_NAME=ksops

# Override the default kustomize executable with the Go built version
COPY --from=ksops-builder /go/bin/kustomize /usr/local/bin/kustomize

# Switch back to non-root user
USER argocd

# Copy the plugin to kustomize plugin path
COPY --from=ksops-builder /go/src/github.com/viaduct-ai/kustomize-sops/* $KUSTOMIZE_PLUGIN_PATH/viaduct.ai/v1/${PKG_NAME}/

ENV HELM_SECRETS_SOPS_PATH=$KUSTOMIZE_PLUGIN_PATH/viaduct.ai/v1/${PKG_NAME}/sops

RUN helm plugin install https://github.com/jkroepke/helm-secrets --version $HELM_SECRETS_VERSION
