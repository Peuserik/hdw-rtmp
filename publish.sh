#!/bin/bash
#
#
#

function=$1
STREAM=$2
DATE=`date +%Y.%m.%d-%H:%M:%S`

echo "$DATE ;Function: $function " >> /srv/www/streams/logs/stream.log
echo "$DATE ;STREAM: $STREAM " >> /srv/www/streams/logs/stream.log

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
