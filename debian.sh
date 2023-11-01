#!/usr/bin/env bash

{ # this ensures the entire script is downloaded #

## Configuration ##
USERNAME=fruithost
GROUP=fruithost
USERID=1010

PHP_VERSION=8.2

has() {
	type "$1" > /dev/null 2>&1
}

color() {
    echo -e "$1\e[39m"
}

debian() {	
	DEBIAN_CODENAME=$(cat /etc/os-release | grep -Po 'VERSION="[0-9]+ \(\K[^)]+')
	DEBIAN_VERSION=$(cat /etc/debian_version)
}

continue() {
	color "Press enter to continue... (\e[47m\e[34mControl + C\e[49m\e[39m for exit)"
	read -p ""
}

reads() {
	read varname
}

packetmanager_update() {
	apt-get update
	apt-get upgrade
	apt-get dist-upgrade
	apt-get -y install dnsutils git tzdata
	dpkg-reconfigure tzdata
	apt-get -y install sudo vim make zip unzip bash-completion curl dbus
	export DEBIAN_FRONTEND=noninteractive
	color "\e[32m[OK]\e[39m Update complete"
}

# fruithost User
add_user() {
	groupadd -g $USERID $USERNAME
	useradd -u $USERID -s /bin/false -d /bin/null -g $GROUP $USERNAME
	color "\e[32m[OK]\e[39m User: $USERNAME, Group: $GROUP"
}

# Set hostname
set_hostname() {
	hostname $varname
	echo "127.0.0.1      $varname" >> /etc/hosts
	hostnamectl set-hostname "$varname"
	color "\e[32m[OK]\e[39m Hostname: $varname"
}

# Webserver
install_webserver() {
	apt-get install apache2 -y
	color "\e[32m[OK]\e[39m Installed:"
	apache2 -v
}

# Adding MariaDB Repository
install_mysql() {
	sudo apt-get -y install apt-transport-https curl
	sudo mkdir -p /etc/apt/keyrings
	sudo curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'
	
	echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://mirror.23m.com/mariadb/repo/$DEBIAN_VERSION/debian $DEBIAN_CODENAME main" >> /etc/apt/sources.list
	
	sudo apt-get update
	sudo apt-get -y install mariadb-server
	color "\e[32m[OK]\e[39m Installed:"
	mysql --version
}

install_php() {
	apt install -y lsb-release apt-transport-https ca-certificates
 	apt update
	apt upgrade
	apt install -y "php$PHP_VERSION"
	apt install -y "php$PHP_VERSION-bcmath" "php$PHP_VERSION-bz2" "php$PHP_VERSION-uploadprogress" "php$PHP_VERSION-cli" "php$PHP_VERSION-curl" "php$PHP_VERSION-dba" "php$PHP_VERSION-fpm" "php$PHP_VERSION-gd" "php$PHP_VERSION-gmp" "php$PHP_VERSION-imap" "php$PHP_VERSION-interbase" "php$PHP_VERSION-intl" "php$PHP_VERSION-ldap" "php$PHP_VERSION-mbstring" "php$PHP_VERSION-mysql" "php$PHP_VERSION-odbc" "php$PHP_VERSION-pgsql" "php$PHP_VERSION-snmp" "php$PHP_VERSION-soap" "php$PHP_VERSION-sqlite3" "php$PHP_VERSION-sybase" "php$PHP_VERSION-xmlrpc" "php$PHP_VERSION-xsl" "php$PHP_VERSION-zip"
	apt install -y "php$PHP_VERSION-dev" php-pear libz-dev
	
	# @ToDo Debug
	apt install -y "php$PHP_VERSION-xdebug"
	
	color "\e[32m[OK]\e[39m Installed:"
	php --version
}

install_pecl() {
	# google-protobuf extension
	pecl channel-update pecl.php.net
	pecl install grpc
}

install_apache2_mods() {
	# PHP-FPM & Apache
	a2enmod proxy_fcgi setenvif headers
	a2enconf "php$PHP_VERSION-fpm"
	a2enmod actions fastcgi alias ssl rewrite
	a2dismod "php$PHP_VERSION"
	
	# protected dirs for apache2
	apt-get install -y apache2-utils libaprutil1 libaprutil1-dbd-mysql
	a2enmod authn_socache dbd authn_dbd authn_dbm
	
	service apache2 restart
}

install_proftp() {
	apt-get install -y proftpd proftpd-mod-mysql
 	apt-get install proftpd-mod-crypto proftpd-mod-wrap
	groupadd -g 2001 ftpd
	useradd -u 2001 -s /bin/false -d /bin/null -g ftpd ftpd
	color "\e[32m[OK]\e[39m Installed:"
	proftpd --version
}

install_rsyslog() {
	# RSyslog
	apt-get install -y rsyslog rsyslog-mysql 
}

create_directorys() {
	mkdir /etc/fruithost
	mkdir /etc/fruithost/temp
	mkdir /var/fruithost
	mkdir /var/fruithost/logs
	mkdir /var/fruithost/users
}

password_generate() {
	set="abcdefghijklmonpqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	n=28
	rand=""
	
	for i in `seq 1 $n`; do
		char=${set:$RANDOM % ${#set}:1}
		rand+=$char
	done
	
	echo $rand
}

fruithost_cleanup() {
	# Directorys
 	rm -rf /etc/fruithost/panel
 	rm -rf /etc/fruithost/bin
 	rm -rf /etc/fruithost/config
 	rm -rf /etc/fruithost/themes
 	rm -rf /etc/fruithost/placeholder
 	rm -rf /etc/fruithost/modules

	# Webserver
	rm /etc/apache2/sites-enabled/global.conf
	rm /etc/apache2/sites-enabled/panel.conf
 	rm /etc/apache2/sites-available/global.conf
	rm /etc/apache2/sites-available/panel.conf

 	# FTP
  	rm /etc/proftpd/modules.conf
  	rm /etc/proftpd/proftpd.conf
  	rm /etc/proftpd/sql.conf

 	# Configurations
	rm /etc/fruithost/.config.php
	rm /etc/fruithost/.mail.php
	rm /etc/fruithost/.security.php
}

fruithost_fetch() {
	# Remove old files
 	fruithost_cleanup
  
	# Grab latest versions
	git clone https://github.com/fruithost/Panel.git /etc/fruithost/panel
	git clone https://github.com/fruithost/Binary.git /etc/fruithost/bin
	git clone https://github.com/fruithost/Config.git /etc/fruithost/config
	git clone https://github.com/fruithost/Themes.git /etc/fruithost/themes
	git clone https://github.com/fruithost/Placeholder.git /etc/fruithost/placeholder
	
	# Adding Modules Folder
	#git clone https://github.com/fruithost/Modules.git /etc/fruithost/modules
	mkdir /etc/fruithost/modules
	
	# Modify permissions
	chmod 0777 /etc/fruithost/bin/cli.php
	chmod 0777 /etc/fruithost/bin/cronjob
	chmod 0777 /etc/fruithost/bin/fruithost.sh
	
	# Adding global scripts
	ln -s /etc/fruithost/bin/fruithost.sh /usr/bin/fruithost
	ln -s /etc/fruithost/bin/fruithost.sh /usr/local/bin/fruithost

  	# Adding Crontabs
	crontab /etc/fruithost/bin/cronjob
}

create_config() {
	mysql_password=$(password_generate)

 	# Config-File
	echo "<?php" >> /etc/fruithost/.config.php
	echo "	# Database Connection" >> /etc/fruithost/.config.php
	echo "	define('DATABASE_HOSTNAME',		'localhost');" >> /etc/fruithost/.config.php
	echo "	define('DATABASE_PORT',			3306);" >> /etc/fruithost/.config.php
	echo "	define('DATABASE_USERNAME',		'fruithost');" >> /etc/fruithost/.config.php
	echo "	define('DATABASE_PASSWORD',		'$mysql_password');" >> /etc/fruithost/.config.php
	echo "	define('DATABASE_NAME',			'fruithost');" >> /etc/fruithost/.config.php
	echo "	define('DATABASE_PREFIX',		'fh_');" >> /etc/fruithost/.config.php
	echo "" >> /etc/fruithost/.config.php
	echo "	# Paths" >> /etc/fruithost/.config.php
	echo "	define('HOST_PATH',			'/var/fruithost/users/');" >> /etc/fruithost/.config.php
	echo "	define('LOG_PATH',			'/var/fruithost/logs/');" >> /etc/fruithost/.config.php
	echo "?>" >> /etc/fruithost/.config.php

	# Mail-File
	echo "<?php" >> /etc/fruithost/.mail.php
	echo "	define('MAIL_EXTERNAL',		false);" >> /etc/fruithost/.mail.php
	echo "	define('MAIL_HOSTNAME',		'smtp.yourhostname.com');" >> /etc/fruithost/.mail.php
	echo "	define('MAIL_PORT',		25);" >> /etc/fruithost/.mail.php
	echo "	define('MAIL_USERNAME',		'no-reply@yourdomain.com');" >> /etc/fruithost/.mail.php
	echo "	define('MAIL_PASSWORD',		'<Password>');" >> /etc/fruithost/.mail.php
	echo "?>" >> /etc/fruithost/.mail.php
	
	# Create MySQL User / Database
	mysql --execute="CREATE DATABASE IF NOT EXISTS fruithost /*\!40100 DEFAULT CHARACTER SET utf8 */;"
	mysql --execute="DROP USER fruithost@localhost;"
	mysql --execute="CREATE USER fruithost@localhost IDENTIFIED BY '${mysql_password}';"
	mysql --execute="GRANT ALL PRIVILEGES ON fruithost.* TO 'fruithost'@'localhost';"
	mysql --execute="FLUSH PRIVILEGES;"
	
	mysql_salt=$(password_generate)
	password_salt=$(password_generate)
	encryption_salt=$(password_generate)

 	# Security-File
	echo "<?php" >> /etc/fruithost/.security.php
	echo "	# DO NOT MODIFY, IT WILL BREAKS ALL YOUR DATA!" >> /etc/fruithost/.security.php
	echo "" >> /etc/fruithost/.security.php
	echo "	define('MYSQL_PASSWORTD_SALT',	'$mysql_salt');" >> /etc/fruithost/.security.php
	echo "	define('RESET_PASSWORD_SALT',	'$password_salt');" >> /etc/fruithost/.security.php
	echo "	define('ENCRYPTION_SALT',	'$encryption_salt');" >> /etc/fruithost/.security.php
	echo "?>" >> /etc/fruithost/.security.php
}

update_config() {
	admin_password=$(password_generate)
	
	# Apache2
	ln -s /etc/fruithost/config/apache2/global.conf /etc/apache2/sites-available/global.conf
	ln -s /etc/fruithost/config/apache2/panel.conf /etc/apache2/sites-available/panel.conf

 	# Set Hostname to ServerName my.fruit.host in /etc/apache2/sites-available/panel.conf
	sed -i -e "s/\$hostname/my\.${HOSTNAME}/g" /etc/apache2/sites-available/panel.conf
 
	a2ensite global panel
	a2dissite 000-default default-ssl
	service apache2 reload

 	# FTP
  	ln -s /etc/fruithost/config/ftp/modules.conf /etc/proftpd/modules.conf
  	ln -s /etc/fruithost/config/ftp/proftpd.conf /etc/proftpd/proftpd.conf
  	ln -s /etc/fruithost/config/ftp/sql.conf /etc/proftpd/sql.conf
   	service proftpd reload
   
	create_config
	
	# Import SQL
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="DROP TABLE IF EXISTS fh_modules;"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="CREATE TABLE fh_modules (id int(11) NOT NULL AUTO_INCREMENT, name varchar(255) DEFAULT NULL, time_enabled datetime DEFAULT NULL ON UPDATE current_timestamp(), time_updated datetime DEFAULT NULL ON UPDATE current_timestamp(), state enum('ENABLED','DISABLED') DEFAULT 'DISABLED', time_deleted datetime DEFAULT NULL, PRIMARY KEY (id)) AUTO_INCREMENT=1;"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="DROP TABLE IF EXISTS fh_modules_settings;"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="CREATE TABLE fh_modules_settings (id int(11) NOT NULL AUTO_INCREMENT, module varchar(255) DEFAULT NULL, \`key\` varchar(255) DEFAULT NULL, value longtext DEFAULT NULL, PRIMARY KEY (id)) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="DROP TABLE IF EXISTS fh_repositorys;"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="CREATE TABLE fh_repositorys (id int(11) NOT NULL AUTO_INCREMENT, url varchar(255) DEFAULT NULL,time_updated datetime DEFAULT NULL, PRIMARY KEY (id)) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;"	
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="INSERT INTO fh_repositorys VALUES ('10', 'https://github.com/fruithost/Modules/', '2020-03-23 13:35:46');"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="DROP TABLE IF EXISTS fh_settings;"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="CREATE TABLE fh_settings (id int(11) NOT NULL AUTO_INCREMENT, \`key\` varchar(255) DEFAULT NULL, value longtext DEFAULT NULL, PRIMARY KEY (id)) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="DROP TABLE IF EXISTS fh_users;"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="CREATE TABLE fh_users (id int(11) NOT NULL AUTO_INCREMENT, username varchar(255) DEFAULT NULL, password varchar(255) DEFAULT NULL, email varchar(255) DEFAULT NULL, lost_enabled enum('YES','NO') DEFAULT 'NO', lost_time datetime DEFAULT NULL ON UPDATE current_timestamp(), lost_token varchar(255) DEFAULT NULL, PRIMARY KEY (id)) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="DROP TABLE IF EXISTS fh_users_data;"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="CREATE TABLE fh_users_data (id int(11) NOT NULL AUTO_INCREMENT, user_id int(11) DEFAULT NULL, phone_number varchar(255) DEFAULT NULL, address varchar(255) DEFAULT NULL, name_first varchar(255) DEFAULT NULL, name_last varchar(255) DEFAULT NULL, PRIMARY KEY (id)) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="DROP TABLE IF EXISTS fh_users_permissions;"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="CREATE TABLE fh_users_permissions (id int(11) NOT NULL AUTO_INCREMENT, user_id int(11) DEFAULT NULL, permission varchar(255) DEFAULT NULL, PRIMARY KEY (id)) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="DROP TABLE IF EXISTS fh_users_settings;"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="CREATE TABLE fh_users_settings (id int(11) NOT NULL AUTO_INCREMENT, user_id int(11) DEFAULT NULL, \`key\` varchar(255) DEFAULT NULL, value longtext DEFAULT NULL, PRIMARY KEY (id)) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;"

	# FTP
 	#mysql --user="fruithost" --password="${mysql_password}" --execute="CREATE USER 'ftp'@'localhost';"
 	#mysql --user="fruithost" --password="${mysql_password}" --execute="GRANT SELECT ON fruithost.fh_users TO 'ftp'@'localhost';"
 	#mysql --user="fruithost" --password="${mysql_password}" --execute="GRANT SELECT, UPDATE ON fruithost.fh_ftp_users TO 'ftp'@'localhost';"
  
	# Create Admin-Account
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="INSERT INTO fh_users VALUES ('1', 'admin', UPPER(SHA2(CONCAT('1', '${mysql_salt}', '${admin_password}'), 512)), 'admin@localhost', 'NO', '2019-05-11 12:35:14', null);"
	
	# Set Permissions
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="INSERT INTO fh_users_permissions VALUES (null, '1', 'USERS::VIEW');"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="INSERT INTO fh_users_permissions VALUES (null, '1', 'MODULES::VIEW');"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="INSERT INTO fh_users_permissions VALUES (null, '1', 'THEMES::VIEW');"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="INSERT INTO fh_users_permissions VALUES (null, '1', 'LOGFILES::VIEW');"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="INSERT INTO fh_users_permissions VALUES (null, '1', 'SERVER::VIEW');"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="INSERT INTO fh_users_permissions VALUES (null, '1', 'SERVER::MANAGE');"
 	
  	mysql --user="fruithost" --password="${mysql_password}" --execute="FLUSH PRIVILEGES;"
 
	color "\e[39mThe Admin-Account was created. You can now login to:"
	color "\e[39mURL: http://my.${HOSTNAME}/"
	color "\e[39mUsername: admin"
	color "\e[39mPassword: ${admin_password}"
	color "\e[91mPlease change the password after the first login!"	
}

install_software() {
	if [ "$EUID" -ne 0 ]
	  then color "\e[91mPlease run as root"
	  exit
	fi

	color "\e[33mWelcome to fruithost installer for Debian [Version=$DEBIAN_VERSION, Codename=$DEBIAN_CODENAME]"
	color "\e[39mDo you want to install all recommended softwares?"
	continue
	
	color "\e[36mUpdate packet manager and install system components..."
	continue
	packetmanager_update
	
	color "\e[36mAdding user to the system..."
	continue
	add_user
	
	color "\e[36mSet the system hostname..."
	reads "Hostname:"
	set_hostname
	
	color "\e[36mInstall Apache2 WebServer..."
	continue
	install_webserver
	
	color "\e[36mInstall MariaDB MySQL-Server..."
	continue
	install_mysql
	
	color "\e[36mInstall PHP..."
	continue
	install_php
	
	color "\e[36mInstall PECL-Extensions..."
	continue
	install_pecl
	
	color "\e[36mInstall Apache2-Mods..."
	continue
	install_apache2_mods
	
	color "\e[36mInstall ProFTP-Server..."
	continue
	install_proftp
	
	color "\e[36mInstall RSyslog..."
	continue
	install_rsyslog
	
	color "\e[36mStarting services..."
	service apache2 restart
	color "\e[32m[OK]\e[39m WebServer"
	service mariadb restart
	color "\e[32m[OK]\e[39m MySQL-Database"
	service proftpd restart
	color "\e[32m[OK]\e[39m FTP-Service"
	service "php$PHP_VERSION-fpm" start
	color "\e[32m[OK]\e[39m PHP-FPM"
}

debian
install_software
	
## Grab latest version fruithost files
create_directorys
fruithost_fetch
update_config
} # this ensures the entire script is downloaded #
