#!/bin/bash
# A script to pick up the env variables for htpassword file creation
# And start nginx
# By @Peuserik
# (c)2017

STREAMUSER="${STREAMUSER:-live}"
STREAMPW="${STREAMPW:-\$apr1\$9AY0gkTk\$KaaNQx6jpkL49i3yYHjUX.}"

STATSUSER="${STATSUSER:-stats}"
STATSPW="${STATSPW:-\$apr1\$i45VBTjn\$tKkodj3Wxthrn6uZQEn8z1}"

# Greeting
WEBHOOK_URL="${WEBHOOK_URL:-'http://testingwebhook'}"

echo "$STREAMUSER:$STREAMPW" > /usr/local/nginx/conf/.htpasswd_stream
echo "$STATSUSER:$STATSPW" > /usr/local/nginx/conf/.htpasswd_stats

TARGET="${TARGET:-localhost}"
KEY="${KEY:-key}"

for p in /srv/www/*.html ; do
  sed -i -e "s/___TARGET___/$TARGET/g" $p
  sed -i -e "s/___KEY___/$KEY/g" $p 
done

if [ "$WEBHOOK_URL" != "http://testingwebhook" ]; then
    echo "$DATE Webhook found! Entering Discord Mode" >> /srv/www/streams/logs/stream.log
    MESSAGE="Hello! I'm is online. You can watch or send streams under https://$TARGET"
    JSON="{\"content\": \"$MESSAGE\"}"
    curl -d "$JSON" -H 'Content-Type: application/json' $WEBHOOK_URL

    echo "$DATE Message send to discord for Server online: $MESSAGE ; $WEBHOOK_URL " >> /srv/www/streams/logs/stream.log
fi

echo "Starting server..."
/usr/local/nginx/sbin/nginx
