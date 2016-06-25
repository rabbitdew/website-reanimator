#!/bin/bash

if [ -f "$1" ] 

then

read -p "Enter domain name: " SITE_NAME
read -p "Enter desired port number for ssh: " NEW_SSH_PORT
read -p "Enter a root mariadb password: "  DATABASE_PASS
read -p "Enter a name for the wp database: " DATABASE_WP
read -p "Enter a username to use that database: " DATABASE_USER
read -p "Enter a password for that username: " DATABASE_WP_PW

yum -y clean all
yum -y upgrade
yum -y install firewalld rsync php-gd php php-mysql policycoreutils mariadb mariadb-server httpd wget

echo -e "yum -y upgrade\nlogger 'slips daily-yum'" >> /etc/cron.daily/daily_yum   
echo -e "Port $NEW_SSH_PORT" >> /etc/ssh/sshd_config

systemctl enable firewalld
systemctl start firewalld
systemctl enable httpd
systemctl start httpd

firewall-cmd --add-port="$NEW_SSH_PORT"/tcp --permanent
firewall-cmd --add-port="$NEW_SSH_PORT"/tcp
firewall-cmd --add-service=http --permanent
firewall-cmd --add-service=http


mv "$1" /tmp

cd /tmp
wget http://wordpress.org/latest.tar.gz
tar -xvJf "$1"

rsync -avP /tmp/var/www/html/ /var/www/html --exclude=lifeBlog

mkdir -p /var/www/html/lifeBlog

tar -xvzf latest.tar.gz

rsync -avP /tmp/wordpress/ /var/www/html/lifeBlog

cd /var/www/html/lifeBlog/
mv -f wp-config-sample.php wp-config.php

systemctl enable mariadb
systemctl start mariadb


mysqladmin -u root password "$DATABASE_PASS"
mysql -u root -p"$DATABASE_PASS" -e "UPDATE mysql.user SET Password=PASSWORD('$DATABASE_PASS') WHERE User='root'"
mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.user WHERE User=''"
mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
mysql -u root -p"$DATABASE_PASS" -e "CREATE DATABASE $DATABASE_WP" 
mysql -u root -p"$DATABASE_PASS" -e "GRANT ALL PRIVILEGES ON $DATABASE_WP.* TO '$DATABASE_USER'@'localhost' IDENTIFIED BY '$DATABASE_WP_PW'"
mysql -u root -p"$DATABASE_PASS" -e "FLUSH PRIVILEGES"

sed -i 's/database_name_here/'$DATABASE_WP'/' /var/www/html/lifeBlog/wp-config.php
sed -i 's/username_here/'$DATABASE_USER'/' /var/www/html/lifeBlog/wp-config.php
sed -i 's/password_here/'$DATABASE_WP_PW'/' /var/www/html/lifeBlog/wp-config.php
  
rsync -avP /tmp/var/www/html/lifeBlog/wp-content/ /var/www/html/lifeBlog/wp-content/
chown -R apache:apache /var/www/html/
chmod 600 /var/www/html/lifeBlog/wp-config.php

#finish installation in web browser, then restore database: 
#mysql -u root -p < /tmp/wpDB.sql 

#rm -rf /tmp/latest.tar.gz /tmp/wordpress /tmp/var/"

echo -e 'ServerName www."$SITE_NAME".com:80\nServerTokens Prod\nServerSignature Off\nTraceEnable Off\n' >> /etc/httpd/conf/httpd.conf

systemctl enable httpd 
systemctl start httpd 
exit 0 

else 
 echo "error: add backup tar as parameter"
 exit 1 
fi

