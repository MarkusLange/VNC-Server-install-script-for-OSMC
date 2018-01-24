#!/bin/bash
# Set UTF-8; e.g. "en_US.UTF-8" or "de_DE.UTF-8":
#export LANG="C.UTF-8"
export LC_ALL="C.UTF-8"

# Tell ncurses to use line characters that work with UTF-8.
export NCURSES_NO_UTF8_ACS=1

separator=":"

function CHECK_ROOT {
  # check if root for future installations
  if [ "$(id -u)" != "0" ];
    then
      echo "This script must be run as root. Like this sudo $0" #1>&2
      exit 1
    else
      echo "This script runs as root." #1>&2
  fi
}

function OPTIONS {
  case $VALUE in
    1) ONE;;
    2) TWO;;
    3) THREE;;
    4) FOUR;;
    5) echo "$VALUE";;
    6) echo "$VALUE";;
    7) echo "$VALUE";;
    8) echo "$VALUE";;
	9) CREATE_SERVICE_FILE;;
  esac
}

function APT_UPDATE {
  apt-get update 1> /dev/null
}

function APT_DISTUPGRADE {
  apt-get -y dist-upgrade
  apt-get -y autoclean
  apt-get -y autoremove
}

function ONE {
  APT_UPDATE
  APT_DISTUPGRADE
  DONE
  sleep 1
  MENU
}

function DONE {
  dialog --backtitle "Installing VNC-Server on OSMC" \
         --infobox "Done" \
         5 20
}

function TWO () {
  FRESH_VARIABLES
  CONFS SET_VARIABLES
}

function TWO_PARTS {
  DONE
  sleep 1
  MENU
}

function THREE {
  CONFS FOUR
}

#function FOUR {
#  echo "4"
#  pass="4444"
#  sed -i /etc/dispmanx_vncserver.conf -e 's/password =.*/password = "'"$pass"'";/'
#  sed -i /etc/dispmanx_vncserver.conf -e 's/port =.*/port = '"$pass"';/'
#}

function FOUR {
  GREP_VARIABLES
  CONFIG SET_VARIABLES
}

function GREP_VARIABLES {
  port=$(egrep "port" /etc/dispmanx_vncserver.conf | egrep -o [0-9]+)
  framerate=$(egrep "frame-rate" /etc/dispmanx_vncserver.conf | egrep -o [0-9]+)
  mypassword=$(egrep "password" /etc/dispmanx_vncserver.conf | cut -d'"' -f2)
}

function FRESH_VARIABLES {
  port="5900"
  framerate="23"
  mypassword=""
}

function COPY_CONF {
  sudo cp dispmanx_vncserver.conf.sample /etc/dispmanx_vncserver.conf
}

function SET_VARIABLES {
  sed -i /etc/dispmanx_vncserver.conf -e 's/port =.*/port = '"$port"';/'
  sed -i /etc/dispmanx_vncserver.conf -e 's/frame-rate =.*/frame-rate = '"$framerate"';/'
  sed -i /etc/dispmanx_vncserver.conf -e 's/password =.*/password = "'"$mypassword"'";/'
}

function APT_INSTALL {
  apt-get install -y build-essential rbp-userland-dev-osmc libvncserver-dev libconfig++-dev unzip 1> /dev/null
}

function CLEAN {
  cd /home/osmc
  
  if [ -d "dispmanx_vnc-master/" ];
    then
      rm -rf dispmanx_vnc-master/
  fi
  
  if [ -d "master.zip" ];
    then
      rm -f master.zip
  fi
}

function GET_DISPMANX {
  cd /home/osmc
  wget -q https://github.com/patrikolausson/dispmanx_vnc/archive/master.zip
  unzip -q -u master.zip -d  /home/osmc/
}

function MAKE_DISPMANX {
  cd dispmanx_vnc-master
  
  # --quiet after make to make it silent
  make --quiet clean
  make --quiet
}

function CREATE_SERVICE_FILE {
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
}

function CONFIG () {
  echo $1
  # Store data to $VALUES variable
  VALUES=$(dialog --title "" \
         --stdout \
         --backtitle "Installing VNC-Server on OSMC" \
         --insecure \
         --output-separator $separator \
         --mixedform "Configuration" \
         10 50 0 \
        "Port:"          1 2 "$port"        1 17 12 0 0 \
        "Framerate:"     2 2 "$framerate"   2 17 12 0 0 \
        "VNC-Password:"  3 2 "$mypassword"  3 17 12 0 1 \
  )
  rep=$?

  # display values just entered
  #echo "$VALUES"
  #echo "$response"

  port=$(echo "$VALUES" | cut -f 1 -d "$separator")
  framerate=$(echo "$VALUES" | cut -f 2 -d "$separator")
  mypassword=$(echo "$VALUES" | cut -f 3 -d "$separator")
  
  #echo "$port"
  #echo "$framerate"
  #echo "$mypassword"
  
  case $rep in
   0) $1;;
   1) MENU;;
   255) MENU;;
  esac
}

function MENU { 
  # Store data to $VALUES variable
  VALUE=$(dialog --backtitle "Installing VNC-Server on OSMC" --title "" \
         --stdout \
         --no-tags \
         --cancel-label "Quit" \
         --menu "Choose a Option" 17 54 9 \
         "1" "OSMC System-Update with clean-up" \
         "2" "Install VNC Server and Service" \
         "3" "Update VNC Server (after a kernel update)" \
         "4" "Change VNC settings" \
         "5" "Start VNC Server (manual, no service)" \
         "6" "Stop VNC Server"\
         "7" "Install VNC Service (on boot)" \
         "8" "Remove VNC Service" \
         "9" "Remove/Clean all up"
  )
  response=$?
  
  # display values just entered
  #echo "$response"
  #echo "$VALUE"
  
  case $response in
   0) OPTIONS;;
   1) ;;
   255) ;;
  esac
}

CHECK_ROOT
MENU