Liste der Befehle, die bei der Installation von Nextcloud in den Proxmox LXC Container verwendet wurden:

Debian LCX Temp
local 30 GB
2 Cores
RAM 2048
Swap 1024


*1. Nextcloud Software*

apt update && apt dist-upgrade -y && reboot

dpkg-reconfigure tzdata
apt install curl unzip apache2 libapache2-mod-php mariadb-server php-xml php-cli php-cgi php-mysql php-mbstring php-gd php-curl php-zip php-mbstring php-intl php-bcmath php-gmp php-imagick libmagickcore-6.q16-6-extra

*2. Service Anpassungen*

*2.1 Apache2* 

a2enmodrewrite
a2enmod 
ssla2ensite 
default-ssl

nano /lib/systemd/system/apache2.service

[Service]
PrivateTmp=false
NoNewPrivileges=yes

nano /etc/apache2/sites-available/000-default.conf
RewriteEngine On    
RewriteCond %{HTTPS} off    
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]

a2ensite 000-default

nano /etc/apache2/sites-available/default-ssl.conf
DocumentRoot /var/www/nextcloud

(Achtung. Youtube erlaubt keine spitzen Klammern. &lt; ist kleiner als und &gt; ist größer als)
<Directory /var/www/nextcloud >   
Options Indexes FollowSymLinks   
AllowOverride All   
Require all granted   
<IfModule mod_rewrite.c >
     RewriteEngine on     
RewriteRule ^\\.well-known/carddav /remote.php/dav [R=301,L]   
 RewriteRule ^\\.well-known/caldav /remote.php/dav [R=301,L]  
</IfModule >
</Directory >

chown -R www-data:www-data /var/www

*2.2 PHP*

nano /etc/php/7.3/apache2/php.ini

memory_limit = 512M

*2.3 MariadDB *
nano /lib/systemd/system/mariadb.service

[Service]
ProtectHome=false
ProtectSystem=false
PrivateDevices=false

systemctl daemon-reload
systemctl restart apache2
systemctl restart mariadb

*2.3.1 Installation (Mariadb)*

mysql_secure_installation

mysql -u root -p 
CREATE DATABASE nextcloud; 
CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY 'nextcloud';
GRANT ALL ON nextcloud.* TO 'nextcloud'@'localhost';
FLUSH PRIVILEGES;

*3. Installation Nextcloud*

su - www-data -s /bin/bash
wget https://download.nextcloud.com/server/releases/nextcloud-22.0.0.zip



unzip nextcloud-22.0.0.zip
