#!/usr/bin/env bash

set -o errexit


if [ "$(uname)" == "Linux" ]; then
    OS="Linux"
else
    echo "This operating system is not supported. The supported operating systems are Linux and Darwin"
    exit 1
fi

for x in cut tar gzip sudo; do
    which $x > /dev/null || (echo "Unable to continue.  Please install $x before proceeding."; exit 1)
done

DISTRO=$(cat /etc/issue /etc/system-release /etc/redhat-release /etc/os-release 2>/dev/null | grep -m 1 -Eo "(Ubuntu|Debian)" || true)

IS_CURL_INSTALLED=$(which curl | wc -l)
if [ $IS_CURL_INSTALLED -eq 0 ]; then
    echo "curl is required to install, please confirm Y/N to install (default Y): "
    read -r CONFIRM_CURL
    if [ "$CONFIRM_CURL" == "Y" ] || [ "$CONFIRM_CURL" == "y" ] || [ "$CONFIRM_CURL" == "" ]; then
        if [ "$DISTRO" == "Ubuntu" ] || [ "$DISTRO" == "Debian" ]; then
            sudo apt-get update
            sudo apt-get install curl -y
        else
            echo "Unable to continue. Please install curl manually before proceeding."; exit 131
        fi
    else
        echo "Unable to continue without curl. Please install curl before proceeding."; exit 131
    fi
fi

# GitHub's URL for the latest release, will redirect.
BASE_URL="https://github.com/fruithost/"
LATEST_URL="$BASE_URL/Panel/raw/master/.version"
DESTDIR="${DESTDIR:-/usr/local/bin}"

# Check for connectivity to https://download.newrelic.com
curl --connect-timeout 10 -IsL "$BASE_URL/Panel.git" > /dev/null || ( echo "Cannot connect to $BASE_URL to download the New Relic CLI. Check your firewall settings. If you are using a proxy, make sure you have set the HTTPS_PROXY environment variable." && exit 132 )

# Create DESTDIR if it does not exist.
#if [ ! -d "$DESTDIR" ]; then 
    #mkdir -m 755 -p "$DESTDIR"
#fi

if [ -z "$VERSION" ]; then
    VERSION=$(curl -sL $LATEST_URL | cut -d "v" -f 2)
fi

echo "Installing fruithost v${VERSION}"

# Run the script in a temporary directory that we know is empty.
#SCRATCH=$(mktemp -d || mktemp -d -t 'tmp')
#cd "$SCRATCH"

function error {
  echo "An error occurred installing the tool."
  echo "The contents of the directory $SCRATCH have been left in place to help to debug the issue."
}

trap error ERR

RELEASE_URL="$BASE_URL/Panel.git"

# Download & unpack the release tarball.
#curl -sL --retry 3 "${RELEASE_URL}" | tar -xz

#if [ "$UID" != "0" ]; then
    #echo "Installing to $DESTDIR using sudo"
   # sudo mv newrelic "$DESTDIR"
   # sudo chmod +x "$DESTDIR/newrelic"
   # sudo chown root:0 "$DESTDIR/newrelic"
#else
   # echo "Installing to $DESTDIR"
   # mv newrelic "$DESTDIR"
    #chmod +x "$DESTDIR/newrelic"
    #chown root:0 "$DESTDIR/newrelic"
#fi

# Delete the working directory when the install was successful.
#rm -r "$SCRATCH"


echo $OS;
echo $DISTRO;
echo $DESTDIR;
echo $VERSION;