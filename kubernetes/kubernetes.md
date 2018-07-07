# Kubernetes

This image can be deployed in kubernetes. You need a config map with environment variables you want to set. for possible variables take a look at [**Default Parameter**](../README.md#default-parameter).

I also added an stateful scaling example together with an internal nfs server to directly deploy to gke.
Please be aware that this is not fro production in any kind. IF you look for a real scaling and more secure solution please take a look at push and pull [directives](https://github.com/arut/nginx-rtmp-module/wiki/Directives) from the rtmp module.

## Simple deploy


### Configmap

``` yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app: rtmp-tv
  name: rtmp-tv-config
  namespace: default
data:
  KEY: kick
  TARGET: $(my-http-server) # Not needed for dynamic kubernetes
  STREAMUSER: 'live'
  STREAMPW: '$apr1$9AY0gkTk$KaaNQx6jpkL49i3yYHjUX.'
```

### Deployment

``` yaml
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: rtmp-tv
  name: rtmp-tv-deployment
  namespace: rtmp
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: rtmp-tv
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: rtmp-tv
    spec:
      containers:
      - env:
        - name: TARGET
          valueFrom:
            configMapKeyRef:
              key: TARGET
              name: rtmp-tv-config
        - name: KEY
          valueFrom:
            configMapKeyRef:
              key: KEY
              name: rtmp-tv-config
        image: peuserik/hdw-rtmp
        imagePullPolicy: Always
        name: hdw-rtmp
        ports:
        - containerPort: 1935
          name: rtmp
        - containerPort: 80
          name: http
        - containerPort: 443
          name: https
        - containerPort: 8080
          name: health
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8080
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      restartPolicy: Always
```

### Service

``` yaml
---
apiVersion: v1
kind: Service
metadata:
  name: rtmp-tv-service
  namespace: rtmp
  labels:
    app: rtmp-tv
spec:
  type: LoadBalancer # use NodePort for our providers
  externalTrafficPolicy: Cluster
#  loadBalancerIP: $(staticIP-from-gce)
  ports:
  - name: rtmp-input
    port: 1935
    targetPort: 1935
    protocol: TCP
  - name: http-port
    port: 80
    protocol: TCP
  - name: https-port
    port: 443
    protocol: TCP
  - name: healthz
    port: 8080
    protocol: TCP
  selector:
    app: rtmp-tv
```

## Stateful scaling