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
    cp /srv/www/dynamic.html /tmp
    sed -i "/'konf',/a '$STREAM'," /tmp/dynamic.html
    cat /tmp/dynamic.html >/srv/www/dynamic.html
elif [ "$function" == "REMOVE" ]; then
    cp /srv/www/dynamic.html /tmp
    sed -i "/'$STREAM',/d" /tmp/dynamic.html
    cat /tmp/dynamic.html >/srv/www/dynamic.html
else
    echo "$DATE ; NO HIT! WRONG PARAMETERS FOR SCRIPT." >> /srv/www/streams/logs/stream.log
fi


# TODO create Folders