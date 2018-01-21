#!/bin/bash
# Set UTF-8; e.g. "en_US.UTF-8" or "de_DE.UTF-8":
#export LANG="C.UTF-8"
export LC_ALL="C.UTF-8"

# Tell ncurses to use line characters that work with UTF-8.
export NCURSES_NO_UTF8_ACS=1

port="5900"
framerate="23"
mypassword=""

function CHECK_SERVICE {
  if [ "`systemctl show dispmanx_vncserver.service -p ActiveState`" = "ActiveState=active" ]
    then
      systemctl stop dispmanx_vncserver.service
  fi
}

function CHECK_ROOT {
  # check if root for future installations
  if [ "$(id -u)" != "0" ];
    then
      echo "This script must be run as root." #1>&2
      exit 1
    else
      echo "This script runs as root." #1>&2
  fi
}

function INSTALL {
  apt-get update 1> /dev/null
  apt-get install -y build-essential rbp-userland-dev-osmc libvncserver-dev libconfig++-dev unzip 1> /dev/null
  
  cd /home/osmc
  wget -q https://github.com/patrikolausson/dispmanx_vnc/archive/master.zip
  
  unzip -q -u master.zip -d  /home/osmc/
  cd dispmanx_vnc-master
  
  # --quiet after make to make it silent
  make clean
  make 

  sudo cp dispmanx_vncserver /usr/bin
  sudo chmod +x /usr/bin/dispmanx_vncserver
}

function CLEAN {
  cd /home/osmc
  sudo rm -rf dispmanx_vnc-master/
  sudo rm -f master.zip
}

function CONFIG {
cat > "/etc/dispmanx_vncserver.conf" <<-EOF
relative = false;
port = $port;
screen = 0;
unsafe = false;
fullscreen = false;
multi-threaded = false;
password = "$mypassword";
frame-rate = $framerate;
downscale = false;
localhost = false;
vnc-params = "";

EOF

cat > "/etc/systemd/system/dispmanx_vncserver.service" <<-EOF
[Unit]
Description=VNC Server
After=network-online.target
Requires=network-online.target

[Service]
Restart=on-failure
RestartSec=30
Nice=15
User=root
Group=root
Type=simple
ExecStartPre=/sbin/modprobe evdev
ExecStart=/usr/bin/dispmanx_vncserver
KillMode=process

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload
systemctl start dispmanx_vncserver.service
systemctl enable dispmanx_vncserver.service
}

function DONE {
  dialog --backtitle "Installing VNC-Server on OSMC" \
         --infobox "Done" \
         5 20
}

function STEPS {
  CHECK_SERVICE
  INSTALL
  CONFIG
  CLEAN
  DONE
  sleep 2
}

CHECK_ROOT
# open fd
exec 3>&1

# Store data to $VALUES variable
VALUES=$(dialog --title "" \
       --backtitle "Installing VNC-Server on OSMC" \
       --insecure \
       --output-separator : \
       --mixedform "Configuration" \
       10 50 0 \
        "Port:"          1 2 "$port"        1 17 12 0 0 \
        "Framerate:"     2 2 "$framerate"   2 17 12 0 0 \
        "VNC-Password:"  3 2 "$mypassword"  3 17 12 0 1 \
2>&1 1>&3)
response=$?

# close fd
exec 3>&-

# display values just entered
#echo "$VALUES"
#echo "$response"

port=$(echo "$VALUES" | cut -f 1 -d ":")
framerate=$(echo "$VALUES" | cut -f 2 -d ":")
mypassword=$(echo "$VALUES" | cut -f 3 -d ":")

#echo "$port"
#echo "$framerate"
#echo "$mypassword"

case $response in
 0) STEPS;;
 1) ;;
 255) ;;
esac
