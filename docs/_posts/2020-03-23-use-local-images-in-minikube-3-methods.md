---
layout: post
comments: true
title: Use local images in minikube with podman - 3 methods
date: 2020-03-23 12:04 +0100
project:
  name: Kubernetes
  qualifier: Minikube
  part: 1
categories: openbsd server
excerpt: An introduction to my OpenBSD server setup.

---

I wanted to to do some kubernetes tests locally with minikube and found out that I couldn't use locally built images. There where three methods depending on the use case that worked for me:

1. Use podman env
2. Use a local registry on host and pull from that in minikube
3. Use a registry in minikube and push into that from the host


# Method 1 - Use podman env

```sh

# start minikube with podman
minikube start --container-runtime=crio-o

# wait until minikube is ready
eval $(minikube podman-env)

# use podman-remote in the same terminal using a local Dockerfile on host, e.g.:
podman-remote build -f Dockerfile example:latest .

# images are then accessible in minikube podman via:
podman-remote run --image localhost/example:latest
```

# Method 2 - Use a local registry on the host

Make name resolution of `registry.local` point to your host

```sh
# update /etc/hosts
printf '%s\t%s\n' '127.0.0.1' 'registry.local' | sudo tee -a /etc/hosts
```

Change the insecure registries entry in your container config file:

```ini
# /etc/containers/registries.conf

[registries.search]
registries = ['docker.io', 'registry.fedoraproject.org', 'quay.io', 'registry.access.redhat.com', 'registry.centos.org']

# If you need to access insecure registries, add the registry's fully-qualified name.
# An insecure registry is one that does not have a valid SSL certificate or only does HTTP.
[registries.insecure]
registries = ['registry.local']


# If you need to block pull access from a registry, uncomment the section below
# and add the registries fully-qualified name.
#
# Docker only
[registries.block]
registries = []

```

Run the local registry and push to it

```sh
# run a local registry on the host
podman run -d -p 5000:5000 --restart=always --name registry registry:2
# or start it if you already did that before
podman start registry

# if you alread have an image tag it correctly
podman tag localhost/example registry.local:5000/example

# push image to local registry
podman push registry.local:5000/example

# start minikube
minikube start --container-runtime=cri-o --insecure-registry="registry.local:5000"

# ssh into minikube and change host as well:
minikube ssh -- eval "printf \''%s\t%s\n'\' \''127.0.0.1'\' \''registry.local'\' | sudo tee -a /etc/hosts"
```

ssh into minikube and add the insecure registry:

```ini
# /etc/containers/registries.conf on minikube vm

[registries.search]
registries = ['docker.io']

[registries.insecure]
registries = ['registry.local']
```


# Method 3 - Use a registry in minikube

Change the insecure registries entry in your container config file:

```ini
# /etc/containers/registries.conf

[registries.search]
registries = ['docker.io', 'registry.fedoraproject.org', 'quay.io', 'registry.access.redhat.com', 'registry.centos.org']

# If you need to access insecure registries, add the registry's fully-qualified name.
# An insecure registry is one that does not have a valid SSL certificate or only does HTTP.
[registries.insecure]
registries = ['registry.local', 'registry.kube']


# If you need to block pull access from a registry, uncomment the section below
# and add the registries fully-qualified name.
#
# Docker only
[registries.block]
registries = []

```



```sh

# start minikube with registry addon
minikube start --container-runtime=crio-o --addons registry

# podman tag localhost/example $(minikube ip):5000/example

printf '%s\t%s\n' "$(minikube ip)" 'registry.kube' | sudo tee -a /etc/hosts

podman push localhost/example $(minikube ip):5000/example
```
