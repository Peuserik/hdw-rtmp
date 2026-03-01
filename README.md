# hdw-rtmp

A Docker image that bundles **NGINX with the RTMP module**, **FFmpeg**, and three browser-based video players into a single, self-contained live-streaming server.

## What is this?

This repository provides everything you need to run your own live-streaming server:

- **Ingest**: Accept a live video stream over RTMP (e.g. from OBS Studio or SimpleScreenRecorder) on port 1935.
- **Transcode**: FFmpeg automatically re-encodes the incoming stream into two quality levels (native resolution and a 640×360 low-bandwidth variant).
- **Serve**: Expose the transcoded stream as HLS and MPEG-DASH for wide client compatibility, and over RTMP for software players such as VLC.
- **Watch**: Three built-in web players let you watch the stream right in your browser, all protected by HTTP Basic Auth over TLS.
- **Deploy**: Ready-made Kubernetes manifests (including a stateful NFS-backed scaling example) are included in the [`kubernetes/`](kubernetes/kubernetes.md) folder.

## Built-in players

| Player | URL (default) | Description |
| ------ | ------------- | ----------- |
| [dash.js](https://github.com/Dash-Industry-Forum/dash.js) | `https://localhost/` | MPEG-DASH player with adaptive bitrate switching. |
| [HDW Player Free](https://www.hdwplayer.com/) | `https://localhost/hdw.html` | Flash-based RTMP player. |
| HTML5 HLS | `https://localhost/iPhone.html` | Native HLS player for Apple/mobile devices. |

Basic Auth protects the web players and HLS/DASH endpoints. The RTMP input port (1935) is unauthenticated by default.

TLS (HTTPS) is required — HTTP requests are automatically redirected to HTTPS.

For Kubernetes deployment instructions see the [**Kubernetes folder**](kubernetes/kubernetes.md).

---

## Contents

- [**Versions**](#versions)
- [**How to use**](#how-to-use)
  - [Build and run the image](#build-and-run-the-image)
  - [Access The Services](#access-the-services)
- [**Default Parameter**](#default-parameter)
- [**Change default configuration**](#set-configuration)
  - [Create new passwords](#create-new-passwords)
- [**Kubernetes**](kubernetes/kubernetes.md)

---

## Versions

* nginx version: 1.16.0
* [rtmp-module for nginx](https://github.com/sergey-dryabzhinsky/nginx-rtmp-module "sergey-dryabzhinsky/nginx-rtmp-module"): master branch
* Ubuntu: 18.04
* [hdw player free](https://www.hdwplayer.com/): 3.0
* [dash player](https://github.com/Dash-Industry-Forum/dash.js): latest
* [**Kubernetes 1.9, 1.11, 1.12**](kubernetes/kubernetes.md) tested
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

``` bash
docker pull peuserik/hdw-rtmp
```

#### Run ##

* You need fullchain, privatekey and dhparam in pem format. They have to be named: fullchain.pem, privkey.pem and dhparam.pem. Like if you generate them with [let's encrypt](https://letsencrypt.org/)
* To start the container with default parameters just use:

``` bash
docker run -d --name rtmp -v $(pwd)/tls:/usr/local/nginx/conf/ssl -p 1935:1935 -p 443:443 peuserik/hdw-rtmp
```

### Access The Services

With default configuration you can access the DASH on localhost
`https://localhost`
You will find a link to hdw and HLS players there
`https://localhost/iPhone.html` or `https://localhost/hdw.html`

--

 *rtmp* entrypoint is default rtmp port 1935. That means using rtmp with your stream program defaults to:
`rtmp://localhost/live/$streamkey`
 **HLS** direct access for software players t.e. VLC is on.
`https://localhost/hls/$streamkey/index.m3u8`
 **DASH**  direct access for software players t.e. VLC is on.
`https://localhost/dash/$streamkey/index.mpd`

#### How to test

With the default configuration you can test the streaming part with for example [OBS Studio](https://obsproject.com/) or [SimpleScreenRecorder](http://www.maartenbaert.be/simplescreenrecorder/) on your local machine. The streaming part will also work on a remote machine. Only The build in webplayers need extra configuration to work on a remote server. How that works and how to change the default password is described in the [Extra configuration](#extra-configuration) part.

#### Test streaming with OBS

* Run the container
* In obs change the "Stream Type" to "Custom Streaming Server"
* In the "URL" field enter the rtmp entrypoint, with default configuration to set locally its `rtmp://localhost/live`
* In the "Stream key" field add the stream app name you want to expose your stream on for example our default "key"
* Start streaming
* OBS shows you in the bottom right an output stream bandwidth

#### Test playing the stream with VLC

* Open [VLC](http://www.videolan.org/vlc/index.html) player
* Click on "Media" -> "Open Network Stream"
* Enter the rtmp url from above `rtmp://localhost/live/$streamkey` In our example we used key as stream key. so the url would be `rtmp://localhost/live/key`
* Or use the hls url like this `http://user:password@localhost/hls/$streamkey/index.m3u8` in our example `http://live:stream@localhost/hls/key/index.m3u8` 

#### Test playing the stream with the hdw player

* go in your browser to `https://localhost`
* supply the user and password for the basic auth
* Activate Flash in your Browser if prompted to.
* Why **Flash?** RTMP is a Flash technology and not natively supported by html5. html5 players will default back to flash when using a rtmp stream as source. If you need something else consider using dash f.e.*
* press play; the video takes a few seconds to start.

*The dafault passwords are shared in the authentification part*

#### Test playing the stream with the dash player

* go in your browser to `https://localhost/dynamic.html`
* supply the user and password for the basic auth
* press play; the video takes a few seconds to start.

---

## Default Parameter

``` none
STREAMUSER=live - sets the user for the streaming page and hls access.
STREAMPW=stream - sets the password for the streaming page and hls access.
STATSUSER=stats - set the user for the stats page.
STATSPW=page - set the password for the stats page.

TARGET=localhost - sets the target stream page for the hdw player configuration. Should point to your Server IP address or DNS Name
KEY=key - set the stream key for your stream. This is only required if you want to use the build in players and change the default stream key you are streaming with.
```

---

## Set configuration ##

To change the default parameters just override them with the run command. The passwords for the basic auth have to be encrypted before given to the run command. For the how see [below](#create-new-passwords)

``` bash
docker run -d --name rtmp -v $(pwd)/tls:/usr/local/nginx/conf/ssl -e STREAMUSER=$USER' -e STREAMPW='$ENCRYPTEDPASSWORD' -e TARGET='my-cool.server.com' -e KEY='mycoolstreamapp' -p 1935:1935 -p 443:443 peuserik/hdw-rtmp
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
docker run -d --name rtmp -v $(pwd)/tls:/usr/local/nginx/conf/ssl -e STREAMUSER='stream' -e STREAMPW='$apr1$9AY0gkTk$KaaNQx6jpkL49i3yYHjUX.' -e TARGET='my-cool.server.com' -p 1935:1935 -p 80:80 peuserik/hdw-rtmp
```

---

# ToDo

- [ ] Add CentOS password generation instructions.
- [ ] Add RTMP authentication support.
