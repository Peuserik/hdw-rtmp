#!/bin/bash
# A script to pick up the env variables for htpassword file creation
# And start nginx
# By @Peuserik
# (c)2017

STREAMUSER="${STREAMUSER:-live}"
STREAMPW="${STREAMPW:-\$apr1\$9AY0gkTk\$KaaNQx6jpkL49i3yYHjUX.}"

STATSUSER="${STATSUSER:-stats}"
STATSPW="${STATSPW:-\$apr1\$i45VBTjn\$tKkodj3Wxthrn6uZQEn8z1}"

echo "$STREAMUSER:$STREAMPW" > /usr/local/nginx/conf/.htpasswd_stream
echo "$STATSUSER:$STATSPW" > /usr/local/nginx/conf/.htpasswd_stats

TARGET="${TARGET:-localhost}"

for p in /srv/www/*.html ; do
  sed -i -e "s/___TARGET___/$TARGET/g" $i
done

nginx
