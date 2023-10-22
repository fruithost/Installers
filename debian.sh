#!/usr/bin/env bash

{ # this ensures the entire script is downloaded #

has() {
	type "$1" > /dev/null 2>&1
}

color() {
    echo -e "$1\e[39m"
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
	groupadd -g 1010 fruithost
	useradd -u 1010 -s /bin/false -d /bin/null -g fruithost fruithost
	color "\e[32m[OK]\e[39m User: fruithost, Group: fruithost"
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
	
	echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://mirror.23m.com/mariadb/repo/10.11/debian bullseye main" >> /etc/apt/sources.list
	
	sudo apt-get update
	sudo apt-get -y install mariadb-server
	color "\e[32m[OK]\e[39m Installed:"
	mysql --version
}

install_php() {
	apt install -y lsb-release apt-transport-https ca-certificates
 	# PHP 8.2 already in prod
	#wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
	#echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php8.2.list
	apt update
	apt upgrade
	apt install -y php8.2
	apt install -y php8.2-bcmath php8.2-bz2 php8.2-cli php8.2-curl php8.2-dba php8.2-fpm php8.2-gd php8.2-gmp php8.2-imap php8.2-interbase php8.2-intl php8.2-ldap php8.2-mbstring php8.2-mysql php8.2-odbc php8.2-pgsql php8.2-snmp php8.2-soap php8.2-sqlite3 php8.2-sybase php8.2-xmlrpc php8.2-xsl php8.2-zip
	apt install -y php8.2-dev php-pear libz-dev
	
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
	a2enconf php8.2-fpm
	a2enmod actions fastcgi alias ssl rewrite
	a2dismod php8.2
	
	# protected dirs for apache2
	apt-get install -y apache2-utils libaprutil1 libaprutil1-dbd-mysql
	a2enmod authn_socache dbd authn_dbd authn_dbm
	
	service apache2 restart
}

install_proftp() {
	apt-get install -y proftpd proftpd-mod-mysql
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

fruithost_fetch() {
	# Remove old files
 	rm /etc/apache2/sites-enabled/global.conf
	rm /etc/apache2/sites-enabled/panel.conf
 	rm /etc/apache2/sites-available/global.conf
	rm /etc/apache2/sites-available/panel.conf
 	rm -rf /etc/fruithost/panel
 	rm -rf /etc/fruithost/bin
 	rm -rf /etc/fruithost/config
 	rm -rf /etc/fruithost/themes
 	rm -rf /etc/fruithost/placeholder
 	rm -rf /etc/fruithost/modules
  
	# Grab latest versions
	git clone https://github.com/fruithost/Panel.git /etc/fruithost/panel
	git clone https://github.com/fruithost/Binary.git /etc/fruithost/bin
	git clone https://github.com/fruithost/Config.git /etc/fruithost/config
	git clone https://github.com/fruithost/Themes.git /etc/fruithost/themes
	git clone https://github.com/fruithost/Placeholder.git /etc/fruithost/placeholder
	git clone https://github.com/fruithost/Modules.git /etc/fruithost/modules
	
	# Modify permissions
	chmod 0777 /etc/fruithost/bin/cli.php
	chmod 0777 /etc/fruithost/bin/cronjob
	chmod 0777 /etc/fruithost/bin/fruithost.sh
	
	# Adding global scripts
	ln -s /etc/fruithost/bin/fruithost.sh /usr/bin/fruithost
	ln -s /etc/fruithost/bin/fruithost.sh /usr/local/bin/fruithost
}

create_config() {
	mysql_password=$(password_generate)
	
	# Delete old config
	rm /etc/fruithost/.config.php
	
	echo "<?php" >> /etc/fruithost/.config.php
	echo "	# Database Connection" >> /etc/fruithost/.config.php
	echo "	define('DATABASE_HOSTNAME',		'localhost');" >> /etc/fruithost/.config.php
	echo "	define('DATABASE_PORT',			3306);" >> /etc/fruithost/.config.php
	echo "	define('DATABASE_USERNAME',		'fruithost');" >> /etc/fruithost/.config.php
	echo "	define('DATABASE_PASSWORD',		'$mysql_password');" >> /etc/fruithost/.config.php
	echo "	define('DATABASE_NAME',			'fruithost');" >> /etc/fruithost/.config.php
	echo "	define('DATABASE_PREFIX',		'fh_');" >> /etc/fruithost/.config.php
	echo "" >> /etc/fruithost/.config.php
	echo "	# Hosting Path" >> /etc/fruithost/.config.php
	echo "	define('HOST_PATH',			'/var/fruithost/users/');" >> /etc/fruithost/.config.php
	echo "?>" >> /etc/fruithost/.config.php
	
	# Create MySQL User / Database
	mysql --execute="CREATE DATABASE IF NOT EXISTS fruithost /*\!40100 DEFAULT CHARACTER SET utf8 */;"
	mysql --execute="DROP USER fruithost@localhost;"
	mysql --execute="CREATE USER fruithost@localhost IDENTIFIED BY '${mysql_password}';"
	mysql --execute="GRANT ALL PRIVILEGES ON fruithost.* TO 'fruithost'@'localhost';"
	mysql --execute="FLUSH PRIVILEGES;"
	
	# Delete old security
	rm /etc/fruithost/.security.php
	
	mysql_salt=$(password_generate)
	password_salt=$(password_generate)
	encryption_salt=$(password_generate)
	
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
	service apache2 relo
 
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

	# Create Admin-Account
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="INSERT INTO fh_users VALUES ('1', 'admin', UPPER(SHA2(CONCAT('1', '${mysql_salt}', '${admin_password}'), 512)), 'admin@localhost', 'NO', '2019-05-11 12:35:14', null);"
	
	# Set Permissions
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="INSERT INTO fh_users_permissions VALUES (null, '1', 'USERS::VIEW');"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="INSERT INTO fh_users_permissions VALUES (null, '1', 'MODULES::VIEW');"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="INSERT INTO fh_users_permissions VALUES (null, '1', 'THEMES::VIEW');"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="INSERT INTO fh_users_permissions VALUES (null, '1', 'LOGFILES::VIEW');"
	mysql --user="fruithost" --password="${mysql_password}" --database="fruithost" --execute="INSERT INTO fh_users_permissions VALUES (null, '1', 'SERVER::VIEW');"
	
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

	color "\e[33mWelcome to fruithost installer for Debian 11"
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
	service php8.2-fpm start
	color "\e[32m[OK]\e[39m PHP-FPM"
}

install_software
	
## Grab latest version fruithost files
create_directorys
fruithost_fetch
update_config

} # this ensures the entire script is downloaded #
