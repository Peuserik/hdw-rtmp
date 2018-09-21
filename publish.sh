#!/bin/bash
#
#
#

function=$1
STREAM=$2
DATE=`date +%Y.%m.%d-%H:%M:%S`

echo "$DATE ;Function: $function " >> /dev/stdout
echo "$DATE ;STREAM: $STREAM " >> /dev/stdout

if [ "$function" == "ADD" ]; then
    cp /srv/www/dynamic.html /tmp
    sed -i "/\[ /a '$STREAM'," /tmp/dynamic.html
    cat /tmp/dynamic.html >/srv/www/dynamic.html
    echo "$DATE Adding STREAM: $STREAM to the strreaming page" >> /dev/stdout
elif [ "$function" == "REMOVE" ]; then
    cp /srv/www/dynamic.html /tmp
    sed -i "/'$STREAM',/d" /tmp/dynamic.html
    cat /tmp/dynamic.html >/srv/www/dynamic.html
    echo "$DATE Removing STREAM: $STREAM from the strreaming page" >> /dev/stdout
else
    echo "$DATE ; NO HIT! WRONG PARAMETERS FOR SCRIPT." >> /dev/stderr
fi
