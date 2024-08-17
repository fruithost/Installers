#!/usr/bin/env bash
set -efu


if [ "$MARIADB_VERSION" = "11.4" ]; then
	MARIADB_VERSION="11.4.3"
fi

MARIA_FILE="mariadb-$MARIADB_VERSION-linux-systemd-x86_64.tar.gz"
MARIA_URL="https://mirror.23m.com/mariadb/mariadb-$MARIADB_VERSION/bintar-linux-systemd-x86_64/$MARIA_FILE"
wget $MARIA_URL



color "\e[1;33m[WARN]\e[0;39m MariaDB can't installed. Your Ubuntu-Version is too old. Trying to install manually."
			
if [ "$MARIADB_VERSION" = "11.4" ]; then
	color "\e[1;33m[WARN]\e[0;39m Fix Version: $MARIADB_VERSION => 11.4.3"
	MARIADB_VERSION="11.4.3"
fi

MARIA_FILE="mariadb-$MARIADB_VERSION-linux-systemd-x86_64"
MARIA_URL="https://mirror.23m.com/mariadb/mariadb-$MARIADB_VERSION/bintar-linux-systemd-x86_64/$MARIA_FILE.tar.gz"

cd /usr/local

[ ! -f "$MARIA_FILE.tar.gz" ] && wget $MARIA_URL

color "Adding MySQL User:"

if [ $(getent group mysql) ]; then
	color "\e[1;33m[WARN]\e[0;39m The group mysql already exists, skipping."
else
	groupadd mysql
	color "\e[32m[OK]\e[39m Group: mysql"
fi

if [ $(getent passwd mysql) ]; then
	color "\e[1;33m[WARN]\e[0;39m The user mysql already exists, skipping."
else
	useradd -g mysql mysql
	color "\e[32m[OK]\e[39m User: mysql"
fi

color "Unpacking in $MARIA_FILE.tar.gz to /usr/local folder..."
[ ! -d "/usr/local/$MARIA_FILE" ] && tar -zxvpf "$MARIA_FILE.tar.gz"
[ ! -L "/usr/local/mysql" ] && color "Create SymLink..." && ln -s "$MARIA_FILE" /usr/local/mysql

color "Start the installation of MariaDB..."
cd "/usr/local/$MARIA_FILE"
./scripts/mariadb-install-db --user=mysql
chown -R root .
chown -R mysql data

color "Registering MariaDB on the System..."
export PATH=$PATH:/usr/local/mysql/bin/

START_TYPE=$(ps --no-headers -o comm 1)

[ ! -d "/etc/systemd/system/mariadb.service.d/" ] && mkdir /etc/systemd/system/mariadb.service.d/

if [ "$START_TYPE" = 'systemd' ]; then
	color "Adding MariaDB to systemd."
	cp "/usr/local/$MARIA_FILE/support-files/systemd/mariadb.service" /etc/systemd/system/mariadb.service
elif [ "$START_TYPE" = 'init' ]; then
	color "Adding MariaDB to init.d."
	cp "/usr/local/$MARIA_FILE/support-files/systemd/mariadb.service" /etc/init.d/mysql.server
fi

	cat > /etc/systemd/system/mariadb.service.d/lxc.conf <<EOF
	[Service]
	ProtectHome=false
	ProtectSystem=false

	# These settings turned out to not be necessary in my case, but YMMV
	#PrivateTmp=false
	#PrivateNetwork=false
	PrivateDevices=false
EOF

	cat > /etc/systemd/system/mariadb.service.d/datadir.conf <<EOF
	[Service]
	ProtectHome=false
	ReadWritePaths=/usr/local/mysql/data
EOF

systemctl daemon-reload
service mariadb start