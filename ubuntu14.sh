# this is how I migrate my site to an ubuntu instance on digitalocean. Note: when server is spun up, my public key is already 
# /root/.ssh/authorized_keys 

if [ -f "$1" ]

then

#read -p "Enter a root mariadb password:"  SQL_ROOTPW
#read -p "Enter a name for the wp database:" DATABASE_WP
#read -p "Enter a username to use that database:" DATABASE_USER
#read -p "Enter a password for that username:" DATABASE_WP_PW
#read -p "Enter a site name: " HOSTNAME
#read -p "Enter a new ssh port: " NEW_SSH_PORT
#read -p "Enter ip address" IP_ADDR
SQL_ROOTPW=?
DATABASE_WP=?
DATABASE_USER=?
HOSTNAME=?
NEW_SSH_PORT=?
IP_ADDR=?
TERM_USER=?


echo "Creating user and hardening ssh..."
sed  -i s/'Port 22'/"Port $NEW_SSH_PORT"/ /etc/ssh/sshd_config
sed -i s/'PermitRootLogin yes'/'PermitRootLogin no'/ /etc/ssh/sshd_config 
sed -i s/"#PasswordAuthentication yes"/"PasswordAuthentication no"/ /etc/ssh/sshd_config
useradd "$TERM_USER" -m
echo "$TERM_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
mkdir -p /home/"$TERM_USER"/.ssh/
mv /root/.ssh/authorized_keys /home/"$TERM_USER"/.ssh/authorized_keys
chown "$TERM_USER":"$TERM_USER" /home/"$TERM_USER"/.ssh/authorized_keys

echo "Setting iptable rules.."
iptables -F
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport "$NEW_SSH_PORT" -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables-save > /slips.fw
echo -e "iptables-restore < /slips.fw\nexit 1" >> /etc/rc.local

echo -e "$IP_ADDR\t$HOSTNAME" >> /etc/hosts

echo "mysql-server mysql-server/root_password select $SQL_ROOTPW" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again select $SQL_ROOTPW" | debconf-set-selections
apt-get update
apt-get -y upgrade
apt-get -y install lamp-server^ wordpress
echo -e "apt-get update && apt-get -y upgrade\nlogger 'slips daily-yum'" >> /etc/cron.daily/daily-upgrade
echo -e "ServerName www.$IP_ADDR:80\nServerTokens Prod\nServerSignature Off\nTraceEnable Off\n" >> /etc/apache2/apache2.conf


echo "Restoring backup..."
tar xvJf "$1" --directory /tmp
rsync -avP /tmp/var/www/html/ /var/www/html --exclude=lifeBlog

echo "Setting up wordpress and restoring database..."
ln -s /usr/share/wordpress /var/www/html/lifeBlog
gzip -d /usr/share/doc/wordpress/examples/setup-mysql.gz
bash /usr/share/doc/wordpress/examples/setup-mysql -n wpDB "$IP_ADDR"
mysql -u root -p"$SQL_ROOTPW" wpDB < /tmp/*.sql 

#echo 'skip-networking' >> /etc/my.cnf

#sed -i 's/database_name_here/'$DATABASE_WP'/' /etc/wordpress/config-$HOSTNAME.php
#sed -i 's/username_here/'$DATABASE_USER'/' /etc/wordpress/config-$HOSTNAME.php
#sed -i 's/password_here/'$DATABASE_WP_PW'/' /etc/wordpress/config-$HOSTNAME.php 
  
rsync -avP /tmp/var/www/html/lifeBlog/wp-content/ /srv/www/wp-content/"$IP_ADDR"/
chown -R www-data:www-data /var/www/html/
chown -R www-data:www-data /srv/www
chown -R www-data:www-data /usr/share/wordpress
chown www-data:www-data /etc/wordpress/config-"$IP_ADDR".php
chmod 600 /etc/wordpress/config-"$IP_ADDR".php
#try that out below
ln -s /etc/wordpress/config-"$IP_ADDR".php /etc/wordpress/config-"$HOSTNAME".php 


exit 0 

else 
 echo "usage: add backup tar"
 exit 1 
fi

