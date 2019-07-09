#! /bin/bash
sudo docker stop unifi
sudo gsutil -m rsync -r -d /unifi gs://belisleonline-unifi-controller/unifi
# tar the certbot dir and copy to storage bucket
sudo tar -czvf certbot.tar /certbot
sudo gsutil cp /certbot.tar gs://belisleonline-unifi-controller/certbot.tar
