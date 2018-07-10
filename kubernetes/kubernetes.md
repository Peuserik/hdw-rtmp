# Kubernetes

This image can be deployed in kubernetes. You need a config map with environment variables you want to set. for possible variables take a look at [**Default Parameter**](../README.md#default-parameter).

I also added an stateful scaling example together with an internal nfs server to directly deploy to gke.
Please be aware that this is not for production in any kind. IF you look for a real scaling and more secure solution please take a look at push and pull [directives](https://github.com/arut/nginx-rtmp-module/wiki/Directives) from the rtmp module.

---
## Create secret

We need the fullchain, the private key and dhparams in pem format. store them in a directory called tls and create a secret out of it

`kubectl create secret generic --namespace rtmp domain.secrets --from-file=tls/`

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

---

## Stateful scaling

Stateful scaling is only available for file based streaming technologies like dash or hls, which write use written fragments from the host disk. if you want to scale dynamically and solely stream based have a look at [push and pull directives](https://github.com/arut/nginx-rtmp-module/wiki/Directives)

We want to make use of that to scale the app if needed. with kubernetes the scaling part is really easy, but persistent volumes don't support natively shared write access. (until now).

To overcome this limitations, we add a small nfs server, which uses a normal persistent volume claim and adds the shared component to it.
We use the example implementation from [kubernertes repository](https://github.com/kubernetes/examples/tree/master/staging/volumes/nfs) as base and change the ReplicationController to deployments, the role to app and add the namespace nfs.

### GKE

#### 1. Create an static IP -regional

It will not work with an global IP, as tcp loadbalancing will not be available.
Control that the **REGION** column is not empty after you got a static IP.

``` bash
$ gcloud compute addresses create web-static-ip --region europe-west1
Created [your project].
---
$ gcloud compute addresses list
NAME           REGION        ADDRESS        STATUS
web-static-ip  europe-west1  35.233.10.228  RESERVED
```

#### 2. Add the IP in your service as loadBalancer IP

`loadBalancerIP: 35.233.10.228`

I also recommend to add an dns record (http_target) for the IP address, that makes it easier and hdw actually accessible.
I use a curl to add and delete entries with my provider. That's very convenient.

#### 3. Create the dependencies

We want to deploy to namespaces, so we need to create them first. Then we deploy the basic nfs server for our scaling approach.

``` bash
kubectl create ns rtmp
kubectl create ns nfs
kubectl create -f nfs*.yaml
```

* control the outcome

``` bash
$ kubectl get pods -n nfs
NAME                         READY     STATUS    RESTARTS   AGE
nfs-server-c69ffdf8c-hklbk   1/1       Running   0          3m
```

#### 4. Create rtmp

We create the application with the added mounts.

``` bash
kubectl create -f rtmp-hdw-k8s-state.yaml
```

After a short while the pod should be up and running. 

* control the outcome

``` bash
kubectl get pods -n rtmp
NAME                                 READY     STATUS    RESTARTS   AGE
rtmp-tv-deployment-9b8fb7847-f4pfg   1/1       Running   0          3m
```

``` bash
$ kubectl describe pods -n rtmp rtmp-tv-deployment-9b8fb7847-f4pfg
Name:           rtmp-tv-deployment-9b8fb7847-f4pfg
Namespace:      rtmp
...
   Mounts:
      /srv/www/streams from nfs (rw)
...
Volumes:
  nfs:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  nfs
    ReadOnly:   false
```

#### 5. Enjoy

If the application runs and you can see the stream, you can now scale the application by

`kubectl scale --replicas 3 deployment rtmp-tv-deployment -n rtmp`

to any number you want. Cause of the nfs storage that is mounted on every pod all pods can read and write when necessary.
If you want longer playlist or have problems with stucking(lagging consider setting dash_cleanup off and/or hls_cleanup off) in the nginx config.

### probs

Cause if the shared filesystem and the activated cleanup you will see errors from pods that tried to cleanup the last fragments but were to slow.
