# hdw-rtmp

A self-contained **live-streaming server** you can deploy with Docker Compose or Kubernetes.
Push a stream from OBS, watch it at multiple qualities in your browser, and monitor all active
streams through a protected dashboard.

---

## v2 – Modern stack (current)

The v2 rewrite replaces the old NGINX-RTMP single-container setup with three focused services:

| Service | Technology | Role |
|---------|-----------|------|
| **mediamtx** | [MediaMTX](https://github.com/bluenviron/mediamtx) + FFmpeg | RTMP ingest, multi-quality transcoding, HLS output, REST stats API |
| **dashboard** | Node.js / Express | JWT-protected web UI – stream list, bitrate, viewers, uptime |
| **nginx** | nginx:alpine | TLS termination, reverse proxy (optional in K8s – use Ingress instead) |

### Features

- **Multiple concurrent streams** – any number of keys can be pushed simultaneously to `rtmp://<host>/live/<key>`
- **Multi-quality transcoding** – FFmpeg automatically produces `source`, `720p`, and `360p` HLS variants per stream
- **Protected dashboard** – JWT-based login; shows live bitrate, viewer count, quality variants, and uptime per stream
- **Real-time updates** – Server-Sent Events push stream stats to the browser every 2 seconds without polling
- **Docker Compose** deployment for single-server use
- **Kubernetes** manifests in [`kubernetes/v2/`](kubernetes/v2/README.md)

### Quick start (Docker Compose)

```bash
# 1. Clone and enter the repo
git clone https://github.com/Peuserik/hdw-rtmp.git && cd hdw-rtmp

# 2. Configure
cp .env.example .env
# Edit .env – set DASHBOARD_PASSWORD and JWT_SECRET

# 3. Place TLS certificates in ./tls/
#    (fullchain.pem + privkey.pem – e.g. from Let's Encrypt)

# 4. Start
docker compose up -d
```

### Access

| URL | Purpose |
|-----|---------|
| `https://localhost/` | Dashboard login |
| `rtmp://localhost/live/<key>` | RTMP stream input (OBS, etc.) |
| `https://localhost/hls/transcoded/<key>_720p/index.m3u8` | HLS 720p direct link |
| `https://localhost/hls/transcoded/<key>_360p/index.m3u8` | HLS 360p direct link |
| `https://localhost/hls/live/<key>/index.m3u8` | HLS source quality |

### Dashboard credentials

Set via environment variables (see `.env.example`):

```
DASHBOARD_USER=admin
DASHBOARD_PASSWORD=<your password>
JWT_SECRET=<random 32-byte hex string>
```

### Kubernetes

See [`kubernetes/v2/README.md`](kubernetes/v2/README.md) for full deployment instructions.

---

## v1 – Legacy stack

> The v1 single-container stack (NGINX + nginx-rtmp-module + HDW / dash.js players) is preserved
> below for reference. New deployments should use the v2 setup above.


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
