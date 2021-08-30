# argocd

[![Build and publish to Docker Hub](https://github.com/shivjm/docker-argocd/actions/workflows/publish.yml/badge.svg)](https://github.com/shivjm/docker-argocd/actions/workflows/publish.yml)

A drop-in ArgoCD Docker image replacement with preinstalled
[KSOPS](https://github.com/viaduct-ai/kustomize-sops#argo-cd-integration),
[jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler)
and [helm-secrets](https://github.com/jkroepke/helm-secrets).

## Issues

<https://github.com/shivjm/docker-argocd/issues>

## Tags

See all available tags at [GitHub (shivjm/docker-argocd)](https://github.com/shivjm/docker-argocd/pkgs/container/argocd/versions).

## Why not use…

### …Docker Hub?

Because their free plan limits you to exactly one [Personal Access Token](https://docs.docker.com/docker-hub/access-tokens/#create-an-access-token). I refuse to use the same token for all my GitHub repositories, and I refuse to upgrade solely to get more tokens.

### …Quay?

Because I refuse to give Red Hat my home address just to host a Docker image.

## Usage

### With Kustomize

Assuming [an ArgoCD manifest](https://github.com/argoproj/argo-cd/tree/master/manifests) can be found at install.yaml, you can use `images` in kustomization.yaml to replace the official ArgoCD image like so:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: argocd

resources:
- ./install.yaml

# wherever a container specifies the `quay.io/argoproj/argocd` image,
# use the specified image and tag instead
images:
- name: quay.io/argoproj/argocd
  newName: ghcr.io/shivjm/argocd
  newTag: v2.1.0
```

### With Helm

Specify `global.image.repository` and `global.image.tag` when installing using [the community-maintained Helm chart](https://github.com/argoproj/argo-helm/tree/master/charts/argo-cd): <kbd>helm install --atomic argocd argo/argo-cd --set global.image.repository=ghcr.io/shivjm/argocd,global.image.tag=v2.1.0</kbd>
