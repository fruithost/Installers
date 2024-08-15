#!/usr/bin/env bash
set -efu

{ # this ensures the entire script is downloaded #

# METHODS #
	color() {
		echo -e "$1\e[39m\033[0;37m"
	}
	
	error() {
		color "\n\e[91m\033[41m                                                                   \e[K"
		color "\e[1;37m\033[41m  ERROR                                                            \e[K"
		color "\e[1;37m\033[41m  $1\e[K"
		color "\e[91m\033[41m                                                                   \e[K\n"
	}


# CALL #
	color "\e[33mUbuntu Preparator!"
	
	if [ `id -u` -ne 0 ]; then
	  error "Please run the installation as root!                             "
	  exit
	fi
	
	read -p "Do you want to install fruithost on your system? (y/n): " go;
	if [ "$go" != 'y' ]; then
		error "You have cancel the installation.                                "
		exit;
	fi
	
	echo "OK"
	
} # this ensures the entire script is downloaded #