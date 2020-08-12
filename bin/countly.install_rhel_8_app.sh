#!/bin/bash
set -e

# if [[ $EUID -ne 0 ]]; then
#    echo "Please execute Countly installation script with a superuser..." 1>&2
#    exit 1
# fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

bash "$DIR/scripts/logo.sh";

sudo yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y
sudo dnf install -y python2 python3 python2-devel python3-devel

# sudo yum install -y ShellCheck
# sudo pip3 install supervisor

#install sendmail
echo "install sendmail"
# sudo dnf -y install sendmail
# sudo systemctl restart sendmail

#install grunt & npm modules
echo "install grunt & npm modules..."
npm install -g grunt-cli --unsafe-perm
( cd "$DIR/.." && npm install --unsafe-perm )

GLIBC_VERSION=$(ldd --version | head -n 1 | rev | cut -d ' ' -f 1 | rev)
if [[ "$GLIBC_VERSION" != "2.25" ]]; then
    (cd "$DIR/.." && npm install argon2 --build-from-source)
fi

cp "$DIR/../frontend/express/public/javascripts/countly/countly.config.sample.js" "$DIR/../frontend/express/public/javascripts/countly/countly.config.js"

# sed -e "s/Defaults requiretty/#Defaults requiretty/" /etc/sudoers > /etc/sudoers2
# mv /etc/sudoers /etc/sudoers.bak
# mv /etc/sudoers2 /etc/sudoers
# chmod 0440 /etc/sudoers

sudo bash "$DIR/scripts/detect.init.sh"

#install numactl
sudo yum install numactl -y

#create configuration files from samples
if [ ! -f "$DIR/../api/config.js" ]; then
	cp "$DIR/../api/config.sample.js" "$DIR/../api/config.js"
fi

if [ ! -f "$DIR/../frontend/express/config.js" ]; then
	cp "$DIR/../frontend/express/config.sample.js" "$DIR/../frontend/express/config.js"
fi

if [ ! -f "$DIR/../plugins/plugins.json" ]; then
	cp "$DIR/../plugins/plugins.default.json" "$DIR/../plugins/plugins.json"
fi

if [ ! -f "/etc/timezone" ]; then
    # sudo echo "Etc/UTC" > /etc/timezone
fi

#install plugins
node "$DIR/scripts/install_plugins"

#get web sdk
countly update sdk-web

# close google services for China area
if ping -c 1 google.com >> /dev/null 2>&1; then
    echo "Pinging Google successful. Enabling Google services."
    countly plugin disable EChartMap
else
    echo "Cannot reach Google. Disabling Google services. You can enable this from Configurations later."
    countly config "frontend.use_google" false
    countly plugin enable EChartMap
fi

#compile scripts for production
cd "$DIR/.." && grunt dist-all

# disable transparent huge pages
#countly thp

# after install call
countly check after install

#finally start countly api and dashboard
countly start

bash "$DIR/scripts/done.sh";

ENABLED=$(getenforce)
if [ "$ENABLED" == "Enforcing" ]; then
  echo -e "\e[31mSELinux is enabled, please disable it or add nginx to exception for Countly to work properly\e[0m"
fi
