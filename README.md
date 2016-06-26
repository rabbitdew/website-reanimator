# website-reanimator

Script builds my website from backup tar on a minimal centos7 box. 

First dump the mysql database and tar it up with the existing site:
tar cvJf notentirelylost_date.tar.xz /var/www/html wp_date.sql

Then run website-reanimator and pass it the backup tar.xz and a public key. Must log back on through console and set some password for the user account created. 
