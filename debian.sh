#!/usr/bin/env bash

{ # this ensures the entire script is downloaded #

has() {
  type "$1" > /dev/null 2>&1
}

echo() {
  command printf %s\\n "$*" 2>/dev/null
}

version() {
  echo "v1.0.0"
}

packetmanager_update() {
	apt-get update
	apt-get upgrade
	apt-get dist-upgrade
	apt-get -Y install dnsutils git tzdata
	dpkg-reconfigure tzdata
	apt-get -Y install sudo vim make zip unzip chkconfig bash-completion curl dbus
	export DEBIAN_FRONTEND=noninteractive
}

install() {
        if [ "$EUID" -ne 0 ]
          then echo "Please run as root"
          exit
        fi

        version()
        packetmanager_update()
}

[ "_$FH_ENV" = "_testing" ] || install

} # this ensures the entire script is downloaded #
