# hdw-rtmp v2 – Kubernetes Deployment Guide

## Overview

The v2 stack consists of three components, each a separate Kubernetes workload:

| Component | Image | Purpose |
|-----------|-------|---------|
| `mediamtx` | `peuserik/hdw-rtmp-mediamtx` | RTMP ingest, HLS output, REST API |
| `dashboard` | `peuserik/hdw-rtmp-dashboard` | Auth + stream stats web UI |
| `nginx` (optional) | `nginx:alpine` | TLS termination (use Ingress instead in K8s) |

---

## Prerequisites

- Kubernetes 1.24+
- `kubectl` configured for your cluster
- An Ingress controller (e.g. [ingress-nginx](https://kubernetes.github.io/ingress-nginx/))
- [cert-manager](https://cert-manager.io/) for automatic TLS (recommended)

---

## 1. Build and push images

```bash
# MediaMTX + FFmpeg
docker build -f Dockerfile.mediamtx -t peuserik/hdw-rtmp-mediamtx:latest .
docker push peuserik/hdw-rtmp-mediamtx:latest

# Dashboard
docker build -f dashboard/Dockerfile dashboard/ -t peuserik/hdw-rtmp-dashboard:latest
docker push peuserik/hdw-rtmp-dashboard:latest
```

## 2. Create the namespace and secrets

```bash
kubectl apply -f kubernetes/v2/namespace.yaml

kubectl create secret generic stream-secrets -n stream \
  --from-literal=DASHBOARD_USER=admin \
  --from-literal=DASHBOARD_PASSWORD='<strong-password>' \
  --from-literal=JWT_SECRET="$(openssl rand -hex 32)"
```

## 3. Deploy

```bash
kubectl apply -f kubernetes/v2/configmap.yaml
kubectl apply -f kubernetes/v2/mediamtx-deployment.yaml
kubectl apply -f kubernetes/v2/dashboard-deployment.yaml
kubectl apply -f kubernetes/v2/services.yaml
```

Edit `kubernetes/v2/ingress.yaml` to set your domain, then:

```bash
kubectl apply -f kubernetes/v2/ingress.yaml
```

## 4. Expose RTMP

RTMP is a TCP protocol and cannot go through an HTTP Ingress. The `rtmp-lb`
`LoadBalancer` service in `services.yaml` exposes port 1935 directly.

```bash
# Get the external IP
kubectl get svc rtmp-lb -n stream
```

Streamers push to: `rtmp://<EXTERNAL-IP>/live/<stream-key>`

## 5. Verify

```bash
kubectl get pods -n stream
kubectl logs -n stream -l app=mediamtx
kubectl logs -n stream -l app=dashboard
```

---

## Scaling

The **dashboard** is stateless and can be scaled freely:

```bash
kubectl scale deployment dashboard -n stream --replicas=3
```

The **mediamtx** deployment handles RTMP stream state in memory. To scale
horizontally, configure MediaMTX push/pull directives so every instance
receives a copy of each stream. See the
[MediaMTX documentation](https://github.com/bluenviron/mediamtx) for details.
