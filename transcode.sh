#!/bin/sh
# transcode.sh – Transcode a source RTMP stream into multiple quality variants.
#
# Usage:   transcode.sh <mtx_path>
# Example: transcode.sh live/mystream
#
# Output paths published back to MediaMTX:
#   transcoded/<name>_source  – passthrough copy (original bitrate)
#   transcoded/<name>_720p    – 1280×720, ~2 Mbps
#   transcoded/<name>_360p    – 640×360,  ~800 kbps

set -e

SRC_PATH="$1"                          # e.g. live/mystream
NAME="${SRC_PATH#live/}"               # e.g. mystream

RTMP_HOST="${RTMP_HOST:-localhost}"
RTMP_PORT="${RTMP_PORT:-1935}"
BASE="rtmp://${RTMP_HOST}:${RTMP_PORT}"

exec ffmpeg -hide_banner -loglevel warning \
  -i "${BASE}/${SRC_PATH}" \
  \
  -map 0 -c:v copy -c:a copy \
    -f flv "${BASE}/transcoded/${NAME}_source" \
  \
  -map 0 \
    -c:v libx264 -preset fast \
    -vf "scale=w=1280:h=720:force_original_aspect_ratio=decrease" \
    -b:v 2000k -maxrate 2200k -bufsize 4000k \
    -c:a aac -b:a 128k -ar 44100 \
    -f flv "${BASE}/transcoded/${NAME}_720p" \
  \
  -map 0 \
    -c:v libx264 -preset fast \
    -vf "scale=w=640:h=360:force_original_aspect_ratio=decrease" \
    -b:v 800k -maxrate 900k -bufsize 1600k \
    -c:a aac -b:a 96k -ar 44100 \
    -f flv "${BASE}/transcoded/${NAME}_360p"
