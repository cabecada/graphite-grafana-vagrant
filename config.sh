#!/bin/bash

apt-get update -y
apt-get install -y apache2 \
libapache2-mod-wsgi \
graphite-web \
graphite-carbon

# Configure Carbon cache
sed -i 's/CARBON_CACHE_ENABLED=false/CARBON_CACHE_ENABLED=true/g' \
/etc/default/graphite-carbon

sed -i 's/ENABLE_LOGROTATION\ =\ False/ENABLE_LOGROTATION = True/g' \
/etc/carbon/carbon.conf

sed -i 's/MAX_CREATES_PER_MINUTE\ =\ 50/MAX_CREATES_PER_MINUTE = 600/g' \
/etc/carbon/carbon.conf

cp /usr/share/doc/graphite-carbon/examples/storage-aggregation.conf.example \
/etc/carbon/storage-aggregation.conf

service carbon-cache start


# Configure Graphite Web
rando=$(openssl rand -base64 32)
sed -i "s/#SECRET_KEY = .UNSAFE_DEFAULT./SECRET_KEY='${rando}'/g" \
/etc/graphite/local_settings.py

sed -i 's/#TIME_ZONE/TIME_ZONE/g' \
/etc/graphite/local_settings.py

graphite-manage createsuperuser --username=admin --email --noinput

graphite-manage syncd

sudo chown _graphite:_graphite /var/lib/graphite/graphite.db

# Configure Apache
a2dissite 000-default
cp /usr/share/graphite-web/apache2-graphite.conf /etc/apache2/sites-available
a2ensite apache2-graphite

sed -i 's/Listen\ 80/Listen 81/g' \
/etc/apache2/ports.conf

sed -i 's/<VirtualHost\ \*:80>/<VirtualHost *:81>/g' \
/etc/apache2/sites-available/apache2-graphite.conf

service apache2 reload

# Install Grafana
echo 'deb https://packagecloud.io/grafana/stable/debian/ wheezy main' >> /etc/apt/sources.list
curl https://packagecloud.io/gpg.key | apt-key add -
apt-get update -y
apt-get install grafana -y

cd /etc/grafana
openssl req -x509 -newkey rsa:2048 -keyout cert.key -out cert.pem -days 3650 \
-nodes -subj '/CN=www.mysterymachine.io/O=The Mystery Machine./C=US'

sed -i 's/;protocol\ =\ http/protocol = https/g' \
/etc/grafana/grafana.ini

sed -i 's/;http_port\ =\ 3000/http_port = 443/g' \
/etc/grafana/grafana.ini

sed -i 's/;cert_file\ =/cert_file = \/etc\/grafana\/cert.pem/g' \
/etc/grafana/grafana.ini

sed -i 's/;cert_key\ =/cert_key = \/etc\/grafana\/cert.key/g' \
/etc/grafana/grafana.ini

setcap 'cap_net_bind_service=+ep'  /usr/sbin/grafana-server

update-rc.d grafana-server defaults 95 10

service grafana-server start
