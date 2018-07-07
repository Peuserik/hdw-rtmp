[![](http://dockerbuildbadges.quelltext.eu/status.svg?organization=peuserik&repository=hdw-rtmp)](https://hub.docker.com/r/peuserik/hdw-rtmp/builds/) [![](https://images.microbadger.com/badges/image/peuserik/hdw-rtmp.svg)](https://microbadger.com/images/peuserik/hdw-rtmp) [![](https://images.microbadger.com/badges/version/peuserik/hdw-rtmp.svg)](https://microbadger.com/images/peuserik/hdw-rtmp) [![](https://images.microbadger.com/badges/commit/peuserik/hdw-rtmp.svg)](https://microbadger.com/images/peuserik/hdw-rtmp)

# **Using it on own risk**. There is no TLS implemented yet.

I'm using basic auth for simple security. Without TLS the username and passwords are transfered in plain text and can be read by every sniffer.

# What is this about

NGINX server with RTMP-module and index page with three players to watch the stream.
hdw player on the main page - free flash player with rtmp capabilities.
html5 video tag for DASH player on "mobile" page and for a HLS player for Apple or HLS compatible devices/software
Simple basic auth for protecting the content.
But only in Source Output right now.

---

## Contents

- [**Versions**](#versions)
- [**How to use**](#how-to-use)
  - [Build and run the image](#build-and-run-the-image)
  - [Access The Services](#access-the-services)
- [**Default Parameter**](#default-parameter)
- [**Change default configuration**](#set-configuration)
  - [Create new passwords](#create-new-passwords)
    - [Ubuntu](#ubuntu)
    - [CentOS/ToDO](#todo)

---

## Versions

* nginx version: 1.12.2
* [rtmp-module for nginx](https://github.com/arut/nginx-rtmp-module "arut/nginx-rtmp-module"): master branch
* Ubuntu: 16.04
* [hdw player free](https://www.hdwplayer.com/): 3.0

---

## How to use

### Build and run the image

#### Clone #

``` bash
git clone https://github.com/Peuserik/hdw-rtmp.git
```

#### Build #

```bash
cd hdw-rtmp
docker build -t peuserik/hdw-rtmp .
```

#### Just pull

* If you just want to use it pull the image from hub.docker.com
```
docker pull peuserik/hdw-rtmp
```

#### Run ##

* To start the container with default paramters just use:

```bash
docker run -d --name rtmp -p 1935:1935 -p 80:80 peuserik/hdw-rtmp
```

### Access The Services

With default configuration you can access the webplayer on localhost
`http://localhost`
You will find an link to the mobile page there for DASH and HLS player
`http://localhost/mobile.html`

--

 *rtmp* entrypoint is default rtmp port 1935. That means using rtmp with your stream programm defaults to:
`rtmp://localhost/live/$streamkey`
 **HLS** direct access for software players t.e. VLC is on 
`http://localhost/hls/$streamkey/index.m3u8`
 **DASH**  direct access for software players t.e. VLC is on
`http://localhost/dash/$streamkey/index.mpd`

#### How to test

With the default configuration you can test the streaming part with for example [OBS Studio](https://obsproject.com/) or [SimpleScreenRecorder](http://www.maartenbaert.be/simplescreenrecorder/) on your local mashine. The streaming part will also work on a remote mashine. Only The build in webplayers need extra configuration to work on a remote server. How that works and how to change the default password is described in the [Extra configuration](#extra-configuration) part.

#### Test streaming with OBS

* Run the container
* In obs change the "Stream Type" to "Custom Streaming Server"
* In the "URL" field enter the rtmp entrypoint, with default configuration to set locally its `rtmp://localhost/live`
* In the "Stream key" field add the stream app name you want to expose your stream on for example our default "key"
* Start streaming
* OBS shows you in the bottom right an output stream bandwith

#### Test playing the stream with VLC

* Open [VLC](http://www.videolan.org/vlc/index.html) player
* Click on "Media" -> "Open Network Stream"
* Enter the rtmp url from above `rtmp://localhost/live/$streamkey` In our example we used key as stream key. so the url would be `rtmp://localhost/live/key`
* Or use the hls url like this `http://user:password@localhost/hls/$streamkey/index.m3u8` in our example `http://live:stream@localhost/hls/key/index.m3u8` 

#### Test playing the stream with the hdw player

* go in your browser to `http://localhost`
* supply the user and password for the basic auth
* Activate Flash in your Browser if prompted to.
* Why **Flash?** RTMP is a Flash technology and not natively supported by html5. html5 players will default back to flash when using a rtmp stream as source. If you need something else consider using dash f.e.*
* press play; the video takes a few seconds to start.

*The dafault passwords are shared in the authentification part*

---

## Default Parameter

```
STREAMUSER=live - sets the user for the streaming page and hls access.
STREAMPW=stream - sets the password for the streaming page and hls access.
STATSUSER=stats - set the user for the stats page.
STATSPW=page - set the password for the stats page.

TARGET=localhost - sets the target stream page for the hdw player configuration. Should point to your Server IP address or DNS Name
KEY=key - set the stream key for your stream. This is only required if you want to use the build in players and change the default stream key you are streaming with.
```

---

## Set configuration ##

To change the default parameters just override them with the run command. The passwords for the basic auth have to be encrypted before given to the run command. For the How see [below](#create-new-passwords)
```bash
docker run -d --name rtmp -e STREAMUSER=$USER' -e STREAMPW='$ENCRYPTEDPASSWORD' -e TARGET='my-cool.server.com' -e KEY='mycoolstreamapp' -p 1935:1935 -p 80:80 peuserik/hdw-rtmp
```

### Create new passwords

The Password has to be entered as encrypted string.

#### Ubuntu

There are multiple methods to create the required string format. I will show here the openssl method

**Openssl**

The command is:
`openssl passwd -apr1`

This command will prompt you for the password you want to use and then again for a confirmation of that password.
It will give you the encrypted password you can use for configurations the two PW parameter.

***_notice_**: the password will not be displayed while typing*

### Example commandline

``` bash
openssl passwd -apr1
Password:
Verifying - Password:
$apr1$9AY0gkTk$KaaNQx6jpkL49i3yYHjUX.
```

#### Complete example

To use it with the image just give it as env variable.
``` bash
docker run -d --name rtmp -e STREAMUSER='stream' -e STREAMPW='$apr1$9AY0gkTk$KaaNQx6jpkL49i3yYHjUX.' -e TARGET='my-cool.server.com' -p 1935:1935 -p 80:80 peuserik/hdw-rtmp
```

---

## Kubernetes

This image can be deployed in kubernetes. You need a config map with environment variables you want to set. for possible variables take a look at [**Default Parameter**](#default-parameter).

### Configmap

``` yaml

```

### Deployment

``` yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: rtmp-tv
  name: rtmp-deployment
  namespace: rtmp
spec:
  selector:
    matchLabels:
      app: rtmp-tv
  template:
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
        - containerport: 80
          name: http
        - containerport: 443
          name: https
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
```

---

# ToDo

To lazy to continue right now.
