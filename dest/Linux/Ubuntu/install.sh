#!/usr/bin/env bash
set -efu
set -o errexit
export DEBIAN_FRONTEND=noninteractive

{ # this ensures the entire script is downloaded #
## Configuration ##
	USERNAME=fruithost
	USER_GROUP=fruithost
	USER_ID=1010
	PHP_VERSION=8.3
	PHP_MODULES=("dev" "pear" "xdebug" "bcmath" "bz2" "uploadprogress" "cli" "curl" "dba" "fpm" "gd" "gmp" "imap" "interbase" "intl" "ldap" "mbstring" "mysql" "odbc" "pgsql" "snmp" "soap" "sqlite3" "sybase" "xmlrpc" "xsl" "zip")
	APACHE_MODS=("proxy_fcgi" "setenvif" "headers" "actions" "fastcgi" "alias" "ssl" "rewrite")
	MARIADB_VERSION=11.4

# METHODS #
	color() {
		echo -e "$1\e[39m\033[0;37m\e[0m"
	}
	
	error() {
		color "\n\e[91m\033[41m\e[K"
		color "\e[1;37m\033[41m\e[K  ERROR"
		color "\e[1;37m\033[41m\e[K  $1\e[K"
		color "\e[91m\033[41m\e[K \n"
	}
	
	has() {
		type "$1" > /dev/null 2>&1
	}
	
	packet() {
		args="$@"
		color "\e[36mInstalling Packets:\e[39m $args"
		export DEBIAN_FRONTEND=noninteractive
		apt -y -qqq install $@
		export DEBIAN_FRONTEND=dialog
	}
	
	packetmanager_update() {
		color "Fetching system informations." 
		. /etc/os-release
		
		color "\e[36mUpdating Packetmanager..."
		apt -qqq update
		apt -qqq upgrade
		apt -qqq dist-upgrade
		
		packet dnsutils git tzdata tzdata jq cron
		packet sudo vim make zip unzip bash-completion curl dbus apt-transport-https
		
		color "\e[32m[OK]\e[39m Update complete"
	}

	# fruithost User
	add_user() {
		if [ $(getent group $USER_GROUP) ]; then
			color "\e[1;33m[WARN]\e[0;39m The group $USER_GROUP already exists, skipping."
		else
			groupadd -g $USER_ID $USERNAME
			color "\e[32m[OK]\e[39m Group: $USER_GROUP"
		fi
		
		if [ $(getent passwd $USERNAME) ]; then
			color "\e[1;33m[WARN]\e[0;39m The user $USERNAME already exists, skipping."
		else
			useradd -u $USER_ID -s /bin/false -d /bin/null -g $USER_GROUP $USERNAME
			color "\e[32m[OK]\e[39m User: $USERNAME"
		fi
	}

	# Set hostname
	set_hostname() {
		hostname $1
		echo "127.0.0.1      $1" >> /etc/hosts
		
		START_TYPE=$(ps --no-headers -o comm 1)
		
		if [ "$START_TYPE" = 'systemd' ]; then
			hostnamectl set-hostname "$1"
		fi
		
		color "\e[32m[OK]\e[39m Hostname: $1"
	}

	# Install Network-Tools
	install_net_tools() {
		packet lshw
		color "\e[32m[OK]\e[39m Installed."
	}

	# Webserver
	install_webserver() {
		add-apt-repository -y ppa:ondrej/apache2 > /dev/null 2>&1
		
		apt -qqq update
		
		packet apache2
		color "\e[32m[OK]\e[39m Installed:"
		apache2 -v
	}

	# Adding MariaDB Repository
	install_mysql() {
		# Check if MariaDB exists!
		
		# EXISTS:	 noble, 24.04 LTS (Noble Numbat)
		# EXISTS:	 jammy, 22.04.4 LTS (Jammy Jellyfish)
		# EXISTS:	 focal, 20.04.6 LTS (Focal Fossa)
		
		# ERROR:	 bionic, 18.04.6 LTS (Bionic Beaver)
		
		mysql_works=("noble" "jammy" "focal")
		
		if printf '%s\0' "${mysql_works[@]}" | grep -Fxqz -- "$UBUNTU_CODENAME"; then
			[ ! -d "/etc/apt/keyrings" ] && mkdir -p /etc/apt/keyrings
		
			color "Getting keyring for signed packages." 
			curl -s -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'
			
			color "Adding MariaDB repository to the system." 
			echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://mirror.23m.com/mariadb/repo/$MARIADB_VERSION/ubuntu $UBUNTU_CODENAME main" | sudo tee /etc/apt/sources.list.d/mariadb.list > /dev/null
		else
			color "\e[1;33m[WARN]\e[0;39m MariaDB can't installed with the latest version. Your Ubuntu-Version is too old. Trying to install manually."
		fi
		
		apt -qqq update
		
		packet mariadb-server
		color "\e[32m[OK]\e[39m Installed:"
		mariadb --version
	}

	install_php() {
		# EXISTS:	 noble, 24.04 LTS (Noble Numbat)
		# EXISTS:	 jammy, 22.04.4 LTS (Jammy Jellyfish)
		# EXISTS:	 focal, 20.04.6 LTS (Focal Fossa)
		
		# ERROR:	 bionic, 18.04.6 LTS (Bionic Beaver)
		
		php_exclude=("bionic")
		
		if printf '%s\0' "${php_exclude[@]}" | grep -Fxqz -- "$UBUNTU_CODENAME"; then
			color "\e[1;33m[WARN]\e[0;39m PHP $PHP_VERSION can't installed with the latest version. Your Ubuntu-Version is too old. Trying to install manually."
			PHP_VERSION=7.2
		else
			add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
		fi
		
		packet lsb-release apt-transport-https ca-certificates libz-dev 
		apt -qqq update
		packet "php$PHP_VERSION"
		
		for i in ${!PHP_MODULES[@]};
		do
			PHP_MODULE=${PHP_MODULES[$i]}
			
			if [ "$(dpkg -s "php$PHP_VERSION-$PHP_MODULE")" = "" ]; then
				if [ "$(apt-cache search --names-only "php$PHP_VERSION-$PHP_MODULE")" = "" ]; then
					if [ "$(apt-cache search --names-only "php-$PHP_MODULE")" = "" ]; then
						color "\e[1;33m[WARN]\e[0;39m The PHP-Module $PHP_MODULE not exists, skipping!"
					else
						packet "php-$PHP_MODULE"
					fi
				else
					packet "php$PHP_VERSION-$PHP_MODULE"
				fi
			else
				color "\e[1;33m[WARN]\e[0;39m The PHP-Module $PHP_MODULE already installed, skipping!"
			fi
		done
		
		color "\e[32m[OK]\e[39m Installed:"
		php --version
	}

	install_pecl() {
		# google-protobuf extension
		# pecl channel-update pecl.php.net
		# pecl install grpc
		echo ".."
	}

	install_apache2_mods() {
		# protected dirs for apache2
		packet apache2-utils libaprutil1 libaprutil1-dbd-mysql
		packet libapache2-mod-authnz-external
		
		# Security & name resolving for apache2 
		packet nscd libapache2-mpm-itk
		
		for i in ${!APACHE_MODS[@]};
		do
			MOD=${APACHE_MODS[$i]}
			
			if [ -f "/etc/apache2/mods-available/$MOD.load" ]; then
				if [ ! -f "/etc/apache2/mods-enabled/$MOD.load" ]; then
					a2enmod "$MOD"
					color "\e[32m[OK]\e[39m Apache-Module $MOD enabled."
				else
					color "\e[1;33m[WARN]\e[0;39m The Apache-Module $MOD already enabled, skipping!"
				fi
			else
				color "\e[1;33m[WARN]\e[0;39m The Apache-Module $MOD not available, skipping!"
			fi
		done
		
		a2disconf "php$PHP_VERSION-fpm"
		a2dismod "php$PHP_VERSION"
		
		service apache2 restart
		echo "OK"
	}

	install_proftp() {
		packet proftpd proftpd-mod-mysql
		
		# Check if ProFTPD-Modules exists!
		
		# EXISTS:	 noble, 24.04 LTS (Noble Numbat)
		# EXISTS:	 jammy, 22.04.4 LTS (Jammy Jellyfish)
		
		# ERROR:	 focal, 20.04.6 LTS (Focal Fossa)
		# ERROR:	 bionic, 18.04.6 LTS (Bionic Beaver)
		
		ftp_works=("noble" "jammy")
		if [[ ${ftp_works[*]} =~ (^|[[:space:]])"$UBUNTU_CODENAME"($|[[:space:]]) ]]; then
			packet proftpd-mod-crypto proftpd-mod-wrap
		else
			color "\e[1;33m[WARN]\e[0;39m The ProFTP-Modules proftpd-mod-crypto & proftpd-mod-wrap are not available, skipping!"
			error "Missing ProFTPD-Mods: proftpd-mod-crypto, proftpd-mod-wrap";
		fi
		
		if [ $(getent group ftpd) ]; then
			color "\e[1;33m[WARN]\e[0;39m The group ftpd already exists, skipping."
		else
			groupadd -g 2001 ftpd
			color "\e[32m[OK]\e[39m Group: ftpd"
		fi
		
		if [ $(getent passwd ftpd) ]; then
			color "\e[1;33m[WARN]\e[0;39m The user ftpd already exists, skipping."
		else
			useradd -u 2001 -s /bin/false -d /bin/null -g ftpd ftpd
			color "\e[32m[OK]\e[39m User: ftpd"
		fi
		
		color "\e[32m[OK]\e[39m Installed:"
		proftpd --version
	}

	install_rsyslog() {
		# RSyslog
		packet rsyslog rsyslog-mysql 
	}

	create_directorys() {
		color "\e[36mCreate structure of the File-System..."
		[ ! -d "/etc/fruithost" ] && mkdir /etc/fruithost
		[ ! -d "/etc/fruithost/temp" ] && mkdir /etc/fruithost/temp
		[ ! -d "/var/fruithost" ] && mkdir /var/fruithost
		[ ! -d "/var/fruithost/logs" ] && mkdir /var/fruithost/logs
		[ ! -d "/var/fruithost/users" ] && mkdir /var/fruithost/users
		color "\e[32m[OK]\e[39m Created 5 Directorys."
	}

	password_generate() {
		set="abcdefghijklmonpqrstuvwxyz-_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
		n=28
		rand=""
		
		for i in `seq 1 $n`; do
			char=${set:$RANDOM % ${#set}:1}
			rand+=$char
		done
		
		echo $rand
	}

	fruithost_cleanup() {
		color "\e[36mClean-Up the File-System..."
		
		# Directorys
		[ -d "/etc/fruithost/panel" ] && rm -rf /etc/fruithost/panel
		[ -d "/etc/fruithost/bin" ] && rm -rf /etc/fruithost/bin
		[ -d "/etc/fruithost/config" ] && rm -rf /etc/fruithost/config
		[ -d "/etc/fruithost/themes" ] && rm -rf /etc/fruithost/themes
		[ -d "/etc/fruithost/placeholder" ] && rm -rf /etc/fruithost/placeholder
		[ -d "/etc/fruithost/modules" ] && rm -rf /etc/fruithost/modules

		# Webserver
		[ -L "/etc/apache2/sites-enabled/global.conf" ] && rm /etc/apache2/sites-enabled/global.conf
		[ -L "/etc/apache2/sites-enabled/panel.conf" ] && rm /etc/apache2/sites-enabled/panel.conf

		# FTP
		[ -L "/etc/proftpd/modules.conf" ] && rm /etc/proftpd/modules.conf
		[ -f "/etc/proftpd/modules.conf" ] && rm /etc/proftpd/modules.conf
		[ -L "/etc/proftpd/proftpd.conf" ] && rm /etc/proftpd/proftpd.conf
		[ -f "/etc/proftpd/proftpd.conf" ] && rm /etc/proftpd/proftpd.conf
		[ -L "/etc/proftpd/sql.conf" ] && rm /etc/proftpd/sql.conf
		[ -f "/etc/proftpd/sql.conf" ] && rm /etc/proftpd/sql.conf
		
		# PHP
		[ -f "/etc/php/$PHP_VERSION/fpm/php.ini" ] && rm "/etc/php/$PHP_VERSION/fpm/php.ini"
		[ -L "/etc/php/$PHP_VERSION/fpm/php.ini" ] && rm "/etc/php/$PHP_VERSION/fpm/php.ini"
		[ -f "/etc/php/$PHP_VERSION/fpm/php-fpm.conf" ] && rm "/etc/php/$PHP_VERSION/fpm/php-fpm.conf"
		[ -L "/etc/php/$PHP_VERSION/fpm/php-fpm.conf" ] && rm "/etc/php/$PHP_VERSION/fpm/php-fpm.conf"
		[ -f "/etc/php/$PHP_VERSION/fpm/pool.d/www.conf" ] && rm "/etc/php/$PHP_VERSION/fpm/pool.d/www.conf"
		[ -L "/etc/fruithost/config/php/users/panel.conf" ] && rm /etc/fruithost/config/php/users/panel.conf
	 
		# Configurations
		[ -f "/etc/fruithost/.config.php" ] && rm /etc/fruithost/.config.php
		[ -f "/etc/fruithost/.mail.php" ] && rm /etc/fruithost/.mail.php
		[ -f "/etc/fruithost/.security.php" ] && rm /etc/fruithost/.security.php
		
		color "\e[32m[OK]\e[39m Cleaned Up."
	}

	fruithost_fetch() {
		# Remove old files
		fruithost_cleanup
	  
		# Grab latest versions
		color "\e[36mFetch Panel from fruithost..."
		git clone -q https://github.com/fruithost/Panel.git /etc/fruithost/panel
		
		color "\e[36mFetch Daemon from fruithost..."
		git clone -q https://github.com/fruithost/Binary.git /etc/fruithost/bin
		
		color "\e[36mFetch Default-Configuration from fruithost..."
		git clone -q https://github.com/fruithost/Config.git /etc/fruithost/config
		
		color "\e[36mFetch Themes from fruithost..."
		git clone -q https://github.com/fruithost/Themes.git /etc/fruithost/themes
		
		color "\e[36mFetch Placeholders from fruithost..."
		git clone -q https://github.com/fruithost/Placeholder.git /etc/fruithost/placeholder
		
		# Adding Modules Folder
		read -p $'Do you want to download all available Modules for fruithost? (y/n): ' go;
		if [ "$go" = 'y' ]; then
			color "\e[36mFetch Modules from fruithost..."
			git clone -q https://github.com/fruithost/Modules.git /etc/fruithost/modules
		else
			color "\e[1;33m[WARN]\e[0;39m Skipping download Modules."
			[ ! -d "/etc/fruithost/modules" ] && mkdir /etc/fruithost/modules
		fi
		
		# Modify permissions
		color "\e[36mSet File-System Permissions..."
		chmod 0777 /etc/fruithost/bin/cli.php
		chmod 0777 /etc/fruithost/bin/cronjob
		chmod 0777 /etc/fruithost/bin/fruithost.sh
		
		[ ! -d "/etc/fruithost/config/php/users/" ] && mkdir /etc/fruithost/config/php/users/
		
		# Adding global scripts
		color "\e[36mRegistering global Scripts..."
		[ ! -L "/usr/bin/fruithost" ] && ln -s /etc/fruithost/bin/fruithost.sh /usr/bin/fruithost
		[ ! -L "/usr/local/bin/fruithost" ] && ln -s /etc/fruithost/bin/fruithost.sh /usr/local/bin/fruithost

		# Adding Crontabs
		crontab /etc/fruithost/bin/cronjob
	}

	create_config() {
		mysql_password=$(password_generate)

		# Config-File
		color "\e[36mCreate Config-File..."
		echo "<?php" > /etc/fruithost/.config.php
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
		echo "	define('CONFIG_PATH',			'/var/fruithost/config/');" >> /etc/fruithost/.config.php
		echo "	define('LOG_PATH',			'/var/fruithost/logs/');" >> /etc/fruithost/.config.php
		echo "?>" >> /etc/fruithost/.config.php

		# Mail-File
		color "\e[36mCreate Mail-File..."
		echo "<?php" > /etc/fruithost/.mail.php
		echo "	define('MAIL_EXTERNAL',		false);" >> /etc/fruithost/.mail.php
		echo "	define('MAIL_HOSTNAME',		'smtp.yourhostname.com');" >> /etc/fruithost/.mail.php
		echo "	define('MAIL_PORT',		25);" >> /etc/fruithost/.mail.php
		echo "	define('MAIL_USERNAME',		'no-reply@yourdomain.com');" >> /etc/fruithost/.mail.php
		echo "	define('MAIL_PASSWORD',		'<Password>');" >> /etc/fruithost/.mail.php
		echo "?>" >> /etc/fruithost/.mail.php
		
		# Ask for Root-password
		#read -p $'Please enter the password of root: ' root_password;
		
		# Create MySQL User / Database
		color "\e[36mCreate Database-User for the Panel..."
		mariadb --socket=/run/mysqld/mysqld.sock --silent --execute="CREATE DATABASE IF NOT EXISTS fruithost;"
		
		USER_EXISTS=$(mariadb --socket=/run/mysqld/mysqld.sock --silent --execute="SELECT COUNT(*) AS U FROM mysql.user WHERE User='fruithost';")
		if [ "$USER_EXISTS" != '0' ]; then
			mariadb --socket=/run/mysqld/mysqld.sock --silent --execute="DROP USER fruithost@localhost;"
		fi
		
		mariadb --socket=/run/mysqld/mysqld.sock --silent --execute="CREATE USER fruithost@localhost IDENTIFIED BY '${mysql_password}';"
		mariadb --socket=/run/mysqld/mysqld.sock --silent --execute="GRANT ALL PRIVILEGES ON fruithost.* TO 'fruithost'@'localhost' WITH GRANT OPTION;"
		mariadb --socket=/run/mysqld/mysqld.sock --silent --execute="GRANT ALL PRIVILEGES ON mysql.* TO 'fruithost'@'localhost' WITH GRANT OPTION;"
		mariadb --socket=/run/mysqld/mysqld.sock --silent --execute="FLUSH PRIVILEGES;"
		
		mysql_salt=$(password_generate)
		password_salt=$(password_generate)
		encryption_salt=$(password_generate)

		# Security-File
		color "\e[36mCreate Security-File..."
		echo "<?php" > /etc/fruithost/.security.php
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
		[ ! -L "/etc/apache2/sites-enabled/global.conf" ] && ln -s /etc/fruithost/config/apache2/global.conf /etc/apache2/sites-enabled/global.conf
		[ ! -L "/etc/apache2/sites-enabled/panel.conf" ] && ln -s /etc/fruithost/config/apache2/panel.conf /etc/apache2/sites-enabled/panel.conf

		# Set Hostname to ServerName my.fruit.host in /etc/fruithost/config/apache2/panel.conf
		# @ToDo Debug $ Check if hostname correctly set!
		sed -i -e "s/\$hostname/my\.${HOSTNAME}/g" /etc/fruithost/config/apache2/panel.conf
		sed -i -e "s/\$phpversion/${PHP_VERSION}/g" /etc/fruithost/config/apache2/panel.conf
		
		if echo $(cat /etc/fruithost/config/apache2/panel.conf) | grep -q "\$hostname"; then
			error "The Hostname-Variable (hostname) can't set. Please fix the variable \$hostname to \"$HOSTNAME\" it on following file:\n/etc/apache2/sites-enabled/panel.conf"
		fi
		
		if echo $(cat /etc/fruithost/config/apache2/panel.conf) | grep -q "\$phpversion"; then
			error "The PHP-Variable (Version) can't set. Please fix the variable \$phpversion to \"$PHP_VERSION\" it on following file:\n/etc/apache2/sites-enabled/panel.conf"
		fi

		#a2ensite global pane
		[ -L "/etc/apache2/sites-enabled/000-default.conf" ] && (a2dissite 000-default)
		[ -L "/etc/apache2/sites-enabled/default-ssl.conf" ] && (a2dissite default-ssl) 
		service apache2 reload

		# PHP
		[ ! -L "/etc/php/$PHP_VERSION/fpm/php.ini" ] && ln -s /etc/fruithost/config/php/php.ini "/etc/php/$PHP_VERSION/fpm/php.ini"
		[ ! -L "/etc/fruithost/config/php/users/panel.conf" ] && ln -s /etc/fruithost/config/php/panel.conf /etc/fruithost/config/php/users/panel.conf
		[ ! -L "/etc/php/$PHP_VERSION/fpm/php-fpm.conf" ] && ln -s /etc/fruithost/config/php/global.conf "/etc/php/$PHP_VERSION/fpm/php-fpm.conf"
		service "php$PHP_VERSION-fpm" restart
	 
		# FTP
		[ ! -L "/etc/proftpd/modules.conf" ] && ln -s /etc/fruithost/config/ftp/modules.conf /etc/proftpd/modules.conf
		[ ! -L "/etc/proftpd/proftpd.conf" ] && ln -s /etc/fruithost/config/ftp/proftpd.conf /etc/proftpd/proftpd.conf
		[ ! -L "/etc/proftpd/sql.conf" ] && ln -s /etc/fruithost/config/ftp/sql.conf /etc/proftpd/sql.conf
		service proftpd reload
	   
		create_config
		
		# Import SQL
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="DROP TABLE IF EXISTS fh_modules;"
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="CREATE TABLE fh_modules (id int(11) NOT NULL AUTO_INCREMENT, name varchar(255) DEFAULT NULL, time_enabled datetime DEFAULT NULL ON UPDATE current_timestamp(), time_updated datetime DEFAULT NULL ON UPDATE current_timestamp(), state enum('ENABLED','DISABLED') DEFAULT 'DISABLED', time_deleted datetime DEFAULT NULL, PRIMARY KEY (id)) AUTO_INCREMENT=1;"
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="DROP TABLE IF EXISTS fh_modules_settings;"
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="CREATE TABLE fh_modules_settings (id int(11) NOT NULL AUTO_INCREMENT, module varchar(255) DEFAULT NULL, \`key\` varchar(255) DEFAULT NULL, value longtext DEFAULT NULL, PRIMARY KEY (id)) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;"
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="DROP TABLE IF EXISTS fh_repositorys;"
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="CREATE TABLE fh_repositorys (id int(11) NOT NULL AUTO_INCREMENT, url varchar(255) DEFAULT NULL,time_updated datetime DEFAULT NULL, PRIMARY KEY (id)) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;"	
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="INSERT INTO fh_repositorys VALUES ('10', 'https://github.com/fruithost/Modules/', '2020-03-23 13:35:46');"
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="DROP TABLE IF EXISTS fh_settings;"
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="CREATE TABLE fh_settings (id int(11) NOT NULL AUTO_INCREMENT, \`key\` varchar(255) DEFAULT NULL, value longtext DEFAULT NULL, PRIMARY KEY (id)) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;"
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="DROP TABLE IF EXISTS fh_users;"
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="CREATE TABLE fh_users (id int(11) NOT NULL AUTO_INCREMENT, username varchar(255) DEFAULT NULL, password varchar(255) DEFAULT NULL, email varchar(255) DEFAULT NULL, lost_enabled enum('YES','NO') DEFAULT 'NO', lost_time datetime DEFAULT NULL ON UPDATE current_timestamp(), lost_token varchar(255) DEFAULT NULL, deleted enum('YES','NO') DEFAULT 'NO', PRIMARY KEY (id)) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;"
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="DROP TABLE IF EXISTS fh_users_data;"
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="CREATE TABLE fh_users_data (id int(11) NOT NULL AUTO_INCREMENT, user_id int(11) DEFAULT NULL, phone_number varchar(255) DEFAULT NULL, address varchar(255) DEFAULT NULL, name_first varchar(255) DEFAULT NULL, name_last varchar(255) DEFAULT NULL, PRIMARY KEY (id)) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;"
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="DROP TABLE IF EXISTS fh_users_permissions;"
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="CREATE TABLE fh_users_permissions (id int(11) NOT NULL AUTO_INCREMENT, user_id int(11) DEFAULT NULL, permission varchar(255) DEFAULT NULL, PRIMARY KEY (id)) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;"
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="DROP TABLE IF EXISTS fh_users_settings;"
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="CREATE TABLE fh_users_settings (id int(11) NOT NULL AUTO_INCREMENT, user_id int(11) DEFAULT NULL, \`key\` varchar(255) DEFAULT NULL, value longtext DEFAULT NULL, PRIMARY KEY (id)) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;"

		# FTP
		#mariadb --socket=/run/mysqld/mysqld.sock --execute="CREATE USER 'ftp'@'localhost';"
		#mariadb --socket=/run/mysqld/mysqld.sock --execute="GRANT SELECT ON fruithost.fh_users TO 'ftp'@'localhost';"
		#mariadb --socket=/run/mysqld/mysqld.sock --execute="GRANT SELECT, UPDATE ON fruithost.fh_ftp_users TO 'ftp'@'localhost';"
	  
		# Create Admin-Account
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="INSERT INTO fh_users VALUES ('1', 'admin', UPPER(SHA2(CONCAT('1', '${mysql_salt}', '${admin_password}'), 512)), 'admin@localhost', 'NO', null, null, 'NO');"
		
		# Set Permissions
		mariadb --socket=/run/mysqld/mysqld.sock --database="fruithost" --execute="INSERT INTO fh_users_permissions VALUES (null, '1', '*');"
		
		mariadb --socket=/run/mysqld/mysqld.sock --execute="FLUSH PRIVILEGES;"
	 	
		# Enable Modules?
		read -p $'Enable all fruithost Modules? (y/n): ' go;
		if [ "$go" = 'y' ]; then
			color "\e[36mEnable all Modules..."
			fruithost install @ --force
			fruithost enable @
		fi

		# Is Running WSL?
		if [[ $(grep WSL /proc/version) ]]; then
			color "\e[36mYou're Linux-Distribution running on Windows-Subsystem for Linux (WSL)."
			read -p $'Do you wan\'t to add Autostart-Service? (y/n): ' autostart;
			if [ "$autostart" = 'y' ]; then
				color "\e[36mEnable Autostart-Services..."
				
				if [[ ! -f "/etc/wsl.conf" ]]; then
					echo -e "[boot]\nsystemd = true\ncommand=\"/etc/rc\"\n" > "/etc/wsl.conf"
				fi
				
				if [[ ! -f "/etc/rc" ]]; then
					echo -e "#!/bin/sh\n# Start system services\nfor i in /etc/rc3.d/S*; do\n  if [ -x $i ]; then\n    $i start\n  fi\ndone\n\n# Run /etc/rc.local if it exists\nif [ -x /etc/rc.local ] ; then\n  /etc/rc.local\nfi" > "/etc/rc"
				fi				
			fi
		fi

		color "\n\e[90m\033[42m\e[K"
		color "\e[90m\033[42m\e[K"
		color "\e[90m\033[47m\e[K"
		color "\e[1;90m\033[1;47m\e[K  Setup was finished!"
		color "\e[1;90m\033[47m\e[K  The Admin-Account was created. You can now login to:\n\e[K"
		color "\e[1;90m\033[47m\e[K  \e[1;35mURL:\e[90m          \e[4;34mhttp://my.${HOSTNAME}/\e[90m\e[K"
		color "\e[1;90m\033[47m\e[K  \e[1;35mUsername:\e[90m     admin\e[K"
		color "\e[1;90m\033[47m\e[K  \e[1;35mPassword:\e[90m     ${admin_password}\e[K"
		color "\e[1;91m\033[47m\e[K                Please change the password after the first login!\e[K"
		color "\e[90m\033[47m\e[K"
		
		read -p $'\nDo you want to store the admin password in root directory? (y/n): ' go;
		if [ "$go" == 'y' ]; then
			echo -e "Password: ${admin_password}" > "/root/admin-password.txt"
			chmod 0400 "/root/admin-password.txt"
			color "\e[1;33m[WARN]\e[0;39m The Password was stored in /root/admin-password.txt."
			color "\e[1;33m[WARN]\e[0;39m Please delete this file after the first usage!"
		fi
	}

	install_software() {
		color "\e[33m\nWelcome to fruithost installer for Ubuntu!"
	
		color "\e[36mUpdate packet manager and install system components..."
		packetmanager_update
		
		color "\e[36mAdding user to the system..."
		add_user
		
		color "\e[36mSet the system hostname..."
		read -p $'Hostname: ' HOSTNAME;
		set_hostname $HOSTNAME

		color "\e[36mInstall Network-Tools..."
		install_net_tools
		
		color "\e[36mInstall Apache2 WebServer..."
		install_webserver
		
		color "\e[36mInstall MariaDB MySQL-Server..."
		install_mysql
		
		color "\e[36mInstall PHP..."
		install_php
		
		color "\e[36mInstall PECL-Extensions..."
		install_pecl
		
		color "\e[36mInstall Apache2-Mods..."
		install_apache2_mods
		
		color "\e[36mInstall ProFTP-Server..." 
		install_proftp
		
		color "\e[36mInstall RSyslog..." 
		install_rsyslog
		
		color "\e[36mStarting services..."
		
		# Webserver
		service apache2 restart || apache_failed=1
		if [ ${apache_failed:-0} -eq 1 ]
		then
			color "\e[31m[ERROR]\e[39m WebServer"
		else
			color "\e[32m[OK]\e[39m WebServer"
		fi
		
		# Database
		service mariadb restart || mariadb_failed=1
		if [ ${mariadb_failed:-0} -eq 1 ]
		then
			color "\e[31m[ERROR]\e[39m MySQL-Database"
		else
			color "\e[32m[OK]\e[39m MySQL-Database"
		fi
		
		# Start FTP
		service proftpd restart || ftp_failed=1
		if [ ${ftp_failed:-0} -eq 1 ]
		then
			color "\e[31m[ERROR]\e[39m FTP-Service"
		else
			color "\e[32m[OK]\e[39m FTP-Service"
		fi
		
		# PHP
		service "php$PHP_VERSION-fpm" restart || php_failed=1
		if [ ${php_failed:-0} -eq 1 ]
		then
			color "\e[31m[ERROR]\e[39m PHP-FPM ($PHP_VERSION)"
		else
			color "\e[32m[OK]\e[39m PHP-FPM ($PHP_VERSION)"
		fi
	}

# CALL #
	if [ `id -u` -ne 0 ]; then
	  error "Please run the installation as root!"
	  exit
	fi
	
	read -p $'Do you want to install fruithost on your system? (y/n): ' go;
	if [ "$go" != 'y' ]; then
		error "You have cancel the installation."
		exit;
	fi

	install_software
	
	## Grab latest version fruithost files
	create_directorys
	fruithost_fetch
	update_config
	
} # this ensures the entire script is downloaded #
