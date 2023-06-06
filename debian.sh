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
	wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
	echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php8.2.list
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
	/etc/init.d/apache2 restart
	color "\e[32m[OK]\e[39m WebServer"
	/etc/init.d/mariadb restart
	color "\e[32m[OK]\e[39m MySQL-Database"
	/etc/init.d/proftpd restart
	color "\e[32m[OK]\e[39m FTP-Service"
}

install_software

} # this ensures the entire script is downloaded #
