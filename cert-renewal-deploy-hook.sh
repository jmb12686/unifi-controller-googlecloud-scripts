#!/bin/sh

## This script is to be executed as part of the 'certbot renew --deploy-hook ' process.
## When certbot renews a cert (that is, the renew command is executed and the existing, live cert
## is to expire in <30 days) this script should be executed.  Assumption is that this script is being executed
## by root, under the certbot context.  This script will perform  the following functions:
##
##              1) Copy the certbot letsencrypt certs to the /unifi/cert/ directory
##              2) Change permissions of unifi/cert files to be owned by unifi_docker_controller user
##              3) Restart the unifi controller to pickup the new certificate
##              TODO:  Add Notification via Email or SMS!!

## These are *actual* directory paths, not the container visible paths ##
#cp -Lrf /certbot/etc/letsencrypt/live/gcp.unifi.belisleonline.com/. /unifi/cert/
#chown -R 9999:9999  /unifi/cert

cp -Lrf /etc/letsencrypt/live/gcp.unifi.belisleonline.com/. /data/letsencrypt/
chown -R 9999:9999 /data/letsencrypt

apk update
apk add docker

docker stop unifi
docker run -dit -m 600m --rm --init -p 8080:8080 \
 -p 8443:8443 -p 3478:3478/udp -p 10001:10001/udp \
 -p 8880:8880 -p 6789:6789 \
 -e TZ='America/New_York' -e RUNAS_UID0=false -e UNIFI_UID=9999 \
 -e UNIFI_GID=9999 -v /unifi:/unifi --name unifi jacobalberty/unifi:stable

exit 0