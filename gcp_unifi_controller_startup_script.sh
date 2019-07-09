#! /bin/bash
apt-get update

#Stackdriver monitoring and logging
curl -sSO https://dl.google.com/cloudagents/install-monitoring-agent.sh
bash install-monitoring-agent.sh
curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
bash install-logging-agent.sh 


fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
cp /etc/fstab /etc/fstab.bak
echo 'swapfile none swap sw 0 0' | tee -a /etc/fstab

##	Unifi presetup
groupadd -g 9999 unifi_docker_controller
useradd -u 9999 -g 9999 unifi_docker_controller
mkdir /unifi
gsutil -m rsync -r -d gs://belisleonline-unifi-controller/unifi /unifi
rm -f /unifi/log/*.log
chown -R 9999:9999 /unifi

## Rehydrate the letsencrypt / certbot dirs from storage bucket tar archive
gsutil cp gs://belisleonline-unifi-controller/certbot.tar /certbot.tar
tar -xzvf /certbot.tar -C /


##### NO LONGER NEEDED, BACKING UP AND REHYDRATING THIS DIRECTORY DAILY AND ON SHUTDOWN INSTEAD    ####
##	Certbot presetup
#mkdir /certbot/etc/letsencrypt/renewal-hooks/deploy
#cp /unifi/cert-renewal-deploy-hook.sh /certbot/etc/letsencrypt/renewal-hooks/deploy/cert-renewal-deploy-hook.sh
#################################################################################################

## Install and start Docker
apt-get install -y docker.io
service docker start

##### NO LONGER NEEDED, BACKING UP AND REHYDRATING THIS DIRECTORY DAILY AND ON SHUTDOWN INSTEAD    ####
## Run certbot docker image to preseed all the required letsencrypt dirs, despite the fact that we probably already have a valid certificate now after rsync from gcloud storage the /unifi/cert dir
#sudo docker run -it --rm \
#-v /certbot/etc/letsencrypt:/etc/letsencrypt \
#-v /certbot/var/lib/letsencrypt:/var/lib/letsencrypt \
#-v /unifi/cert:/data/letsencrypt \
#-v /certbot/var/log/letsencrypt:/var/log/letsencrypt \
#-p 443:443 \
#-p 80:80 \
#certbot/certbot \
#certonly --standalone \
#--preferred-challenges http \
#--email jmb186@gmail.com --agree-tos --no-eff-email \
#-d gcp.unifi.belisleonline.com
#######################################################

##### NO LONGER NEEDED, BACKING UP AND REHYDRATING THIS DIRECTORY DAILY AND ON SHUTDOWN INSTEAD    ####
##Fresh certs are @ '/certbot/etc/letsencrypt/live/gcp.unifi.belisleonline.com' with root file permissions
##Copy fresh certs to a dir for unifi and chown to unifi controller user
#cp -Lrf /certbot/etc/letsencrypt/live/gcp.unifi.belisleonline.com/. /unifi/cert/
#chown -R 9999:9999  /unifi/cert
#######################################################



##	Start Unifi Controller docker image
docker pull jacobalberty/unifi:stable
sudo docker run -dit -m 600m --rm --init -p 8080:8080 \
 -p 8443:8443 -p 3478:3478/udp -p 10001:10001/udp \
 -p 8880:8880 -p 6789:6789 \
 -e TZ='America/New_York' -e RUNAS_UID0=false -e UNIFI_UID=9999 \
 -e UNIFI_GID=9999 -v /unifi:/unifi --name unifi jacobalberty/unifi:stable


echo "0 6 * * * root (gsutil -m rsync -r -d /unifi gs://belisleonline-unifi-controller/unifi) 2>&1 | logger -t unifi-backup-cron" >> /etc/cron.d/backupunifidir
echo "0 7 * * * root (docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v /certbot/etc/letsencrypt:/etc/letsencrypt -v /certbot/var/lib/letsencrypt:/var/lib/letsencrypt -v /unifi/cert:/data/letsencrypt -v /certbot/var/log/letsencrypt:/var/log/letsencrypt -p 443:443 -p 80:80 certbot/certbot renew --quiet) 2>&1 | logger -t certbot-renew-cron" >> /etc/cron.d/certbotrenewal
echo "0 8 * * * root (tar -czvf certbot.tar /certbot && gsutil cp /certbot.tar gs://belisleonline-unifi-controller/certbot.tar) 2>&1 | logger -t certbot-backup-cron" >> /etc/cron.d/backupcertbotdir

gsutil cp gs://belisleonline-unifi-controller/etc/google-fluentd/config.d/unifi.conf /etc/google-fluentd/config.d/unifi.conf
gsutil cp gs://belisleonline-unifi-controller/etc/google-fluentd/config.d/certbot.conf /etc/google-fluentd/config.d/certbot.conf
service google-fluentd reload