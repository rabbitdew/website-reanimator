#!/bin/bash

if [ -f "$1" ] 

then

read -p "Enter domain name: " SITE_NAME
read -p "Enter a new terminal user: " TERM_USER
read -p "Enter desired port number for ssh: " NEW_SSH_PORT
read -p "Enter a root mariadb password: "  SQL_ROOTPW
read -p "Enter name of the wp database: " DATABASE_WP
read -p "Enter a username to use that database: " DATABASE_USER
read -p "Enter a password for that username: " DATABASE_WP_PW

hostnamectl set-hostname "$SITE_NAME"

useradd "$TERM_USER" -G wheel 
mkdir /home/"$TERM_USER"/.ssh

cat "$2" > /home/"$TERM_USER"/.ssh/authorized_keys
sed -i 's/PasswordAuthentication yes'/'PasswordAuthentication no'/ /etc/ssh/sshd_config
sed -i s/"#Port 22"/"Port $NEW_SSH_PORT"/ /etc/ssh/sshd_config
echo -e "Port $NEW_SSH_PORT" >> /etc/ssh/sshd_config
semanage port -a -t ssh_port_t -p tcp "$NEW_SSH_PORT"
systemctl restart sshd

yum -y clean all
yum -y upgrade
yum -y install firewalld rsync php-gd php php-mysql policycoreutils-python mariadb mariadb-server httpd wget


echo -e "yum -y upgrade\nlogger 'slips daily-yum'" >> /etc/cron.daily/daily_yum   

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
wget https://wordpress.org/latest.tar.gz
tar -xvJf "$1"

rsync -avP /tmp/var/www/html/ /var/www/html --exclude=lifeBlog

mkdir -p /var/www/html/lifeBlog

tar -xvzf latest.tar.gz

rsync -avP /tmp/wordpress/ /var/www/html/lifeBlog

cd /var/www/html/lifeBlog/
mv -f wp-config-sample.php wp-config.php

systemctl enable mariadb
systemctl start mariadb


mysqladmin -u root password "$SQL_ROOTPW"
mysql -u root -p"$SQL_ROOTPW" -e "UPDATE mysql.user SET Password=PASSWORD('$SQL_ROOTPW') WHERE User='root'"
mysql -u root -p"$SQL_ROOTPW" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
mysql -u root -p"$SQL_ROOTPW" -e "DELETE FROM mysql.user WHERE User=''"
mysql -u root -p"$SQL_ROOTPW" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
mysql -u root -p"$SQL_ROOTPW" -e "CREATE DATABASE $DATABASE_WP" 
mysql -u root -p"$SQL_ROOTPW" -e "GRANT ALL PRIVILEGES ON $DATABASE_WP.* TO '$DATABASE_USER'@'localhost' IDENTIFIED BY '$DATABASE_WP_PW'"
mysql -u root -p"$SQL_ROOTPW" -e "FLUSH PRIVILEGES"
mysql -u root -p"$SQL_ROOTPW" "$DATABASE_WP" < /tmp/*.sql 
echo 'skip-networking' >> /etc/my.cnf

sed -i 's/database_name_here/'$DATABASE_WP'/' /var/www/html/lifeBlog/wp-config.php
sed -i 's/username_here/'$DATABASE_USER'/' /var/www/html/lifeBlog/wp-config.php
sed -i 's/password_here/'$DATABASE_WP_PW'/' /var/www/html/lifeBlog/wp-config.php
  
rsync -avP /tmp/var/www/html/lifeBlog/wp-content/ /var/www/html/lifeBlog/wp-content/
chown -R apache:apache /var/www/html/
chmod 600 /var/www/html/lifeBlog/wp-config.php

rm -rf /tmp/latest.tar.gz /tmp/wordpress /tmp/var/

echo -e "ServerName www.$SITE_NAME.com:80\nServerTokens Prod\nServerSignature Off\nTraceEnable Off\n" >> /etc/httpd/conf/httpd.conf

systemctl enable httpd 
systemctl start httpd 
exit 0 

else 
 echo "usage: add backup tar and public key as parameter"
 exit 1 
fi
