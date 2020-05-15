#!/bin/bash
#
#
#

function=$1
STREAM=$2
WEBHOOK_URL="${WEBHOOK_URL:-'http://testingwebhook'}"
DATE=`date +%Y.%m.%d-%H:%M:%S`
MESSAGE=""

echo "$DATE ;Function: $function " >> /srv/www/streams/logs/stream.log
echo "$DATE ;STREAM: $STREAM " >> /srv/www/streams/logs/stream.log
echo "$DATE ;WEBHOOK_URL: $WEBHOOK_URL " >> /srv/www/streams/logs/stream.log

if [ "$function" == "ADD" ]; then
    cp /srv/www/player/js/peuserik.js /tmp
    sed -i "/\[ /a '$STREAM'," /tmp/peuserik.js
    cat /tmp/peuserik.js > /srv/www/player/js/peuserik.js
    echo "$DATE Adding STREAM: $STREAM to the strreaming page" >> /srv/www/streams/logs/stream.log
elif [ "$function" == "REMOVE" ]; then
    cp /srv/www/player/js/peuserik.js /tmp
    sed -i "/'$STREAM',/d" /tmp/peuserik.js
    cat /tmp/peuserik.js > /srv/www/player/js/peuserik.js
    echo "$DATE Removing STREAM: $STREAM from the strreaming page" >> /srv/www/streams/logs/stream.log
else
    echo "$DATE ; NO HIT! WRONG PARAMETERS FOR SCRIPT." >> /srv/www/streams/logs/stream.log
fi

# Curl config
PING="${TARGET:-localhost}"

if [ "$WEBHOOK_URL" != "http://testingwebhook" ]; then
    echo "$DATE Webhook found! Entering Discord Mode" >> /srv/www/streams/logs/stream.log
    if [ "$function" == "ADD" ]; then
        # Write message for going live
        MESSAGE="Hey! $STREAM is online. You can join the stream under https://$PING"
        JSON="{\"content\": \"$MESSAGE\"}"
        curl -d "$JSON" -H 'Content-Type: application/json' $WEBHOOK_URL

        echo "$DATE Message send to discord for going live for Stream: $STREAM with " >> /srv/www/streams/logs/stream.log
    elif [ "$function" == "REMOVE" ]; then
        # Write message for going offline
        MESSAGE="$STREAM is going offline. Thank you for your stream!"
        JSON="{\"content\": \"$MESSAGE\"}"
        curl -d "$JSON" -H 'Content-Type: application/json' $WEBHOOK_URL

        echo "$DATE Message send to discord for going offline for Stream: $STREAM " >> /srv/www/streams/logs/stream.log
    else
        echo "$DATE ; NO HIT! WRONG PARAMETERS FOR SCRIPT. in Discord webhook" >> /srv/www/streams/logs/stream.log
    fi
else
    echo "No Webhook found"  >> /srv/www/streams/logs/stream.log
fi