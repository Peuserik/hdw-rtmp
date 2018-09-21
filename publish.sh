#!/bin/bash
#
#
#

function=$1
STREAM=$2
DATE=`date +%Y.%m.%d-%H:%M:%S`



echo "$DATE ;Function: $function " >> /srv/www/log/stream.log
echo "$DATE ;STREAM: $STREAM " >> /srv/www/log/stream.log

if [ "$function" == "ADD" ]; then
    cp /srv/www/dynamic2.html /tmp
    sed -i "/'konf',/a '$STREAM'," /tmp/dynamic.html
    cat /tmp/dynamic2.html >/srv/www/dynamic.html
elif [ "$function" == "REMOVE" ]; then
    cp /srv/www/dynamic2.html /tmp
    sed -i "/'$STREAM',/d" /tmp/dynamic.html
    cat /tmp/dynamic2.html >/srv/www/dynamic.html
else
    echo "$DATE ; NO HIT! WRONG PARAMETERS FOR SCRIPT." >> /srv/www/log/stream.log
fi


# TODO create Folders
