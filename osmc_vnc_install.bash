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

function CHECK_SERVICE_ACTIVE {
  if [ "`systemctl show dispmanx_vncserver.service -p ActiveState`" = "ActiveState=active" ]
    then
      systemctl stop dispmanx_vncserver.service
  fi
}
function CHECK_SERVICE_INACTIVE {
  if [ "`systemctl show dispmanx_vncserver.service -p ActiveState`" = "ActiveState=inactive" ]
    then
      systemctl start dispmanx_vncserver.service
  fi
}

function CHECK_SERVICE_ENABLED {
  if [ "`systemctl is-enabled dispmanx_vncserver.service`" = "enabled" ]
    then
      systemctl disable dispmanx_vncserver.service
  fi
}

function CHECK_SERVICE_DISABLED {
  if [ "`systemctl is-enabled dispmanx_vncserver.service`" = "disabled" ]
    then
      systemctl enable dispmanx_vncserver.service
  fi
}

function OPTIONS {
  case $VALUE in
    1) OSMC_UPATE;;
    2) INSTALL_VNC_SERVER_AND_SERVICE;;
	3) REMOVE_VNC_SERVER_AND_SERVICE;;
    4) UPDATE_VNC_SERVER;;
    5) CHANGE_VNC_SETTINGS;;
    6) START_VNC;;
    7) STOP_VNC;;
    8) ACTIVATE_VNC_SERVICE;;
    9) DEACTIVATE_VNC_SERVICE;;
  esac
}

function APT_UPDATE {
  apt-get update 1> /dev/null
  apt-get -y dist-upgrade 1> /dev/null
}

function APT_CLEAN {
  apt-get -y autoclean
  apt-get -y autoremove
}

function OSMC_UPATE {
  echo "starting"
  APT_UPDATE
  APT_CLEAN
  REBOOT_FOLLOWS
  sleep 1
  clear
  reboot
}

function REBOOT_FOLLOWS {
  dialog --backtitle "Installing VNC-Server on OSMC" \
         --infobox "Reboot follows" \
         5 20
}

function DONE {
  dialog --backtitle "Installing VNC-Server on OSMC" \
         --infobox "Done" \
         5 20
  sleep 1
}

function EXIT {
  dialog --backtitle "Installing VNC-Server on OSMC" \
         --infobox "Exit" \
         5 20
  sleep 1
  clear
}

function INSTALL_VNC_SERVER_AND_SERVICE () {
  echo -n "starting"
  APT_UPDATE
  APT_INSTALL
  CREATE_VNC_SERVER
  COPY_CONF
  CLEANUP_INSTALL
  CREATE_SERVICE_FILE
  systemctl daemon-reload
  ACTIVATE_VNC_SERVICE
  GREP_VARIABLES
  CONFIG --nocancel
}

function UPDATE_VNC_SERVER {
  echo -n "starting"
  APT_UPDATE
  DEACTIVATE_VNC_SERVICE
  CREATE_VNC_SERVER
  CLEANUP_INSTALL
  ACTIVATE_VNC_SERVICE
  DONE
  MENU
}

function CHANGE_VNC_SETTINGS {
  GREP_VARIABLES
  CONFIG
}

function START_VNC {
  CHECK_SERVICE_INACTIVE
}

function STOP_VNC {
  CHECK_SERVICE_ACTIVE
}

function ACTIVATE_VNC_SERVICE {
  CHECK_SERVICE_DISABLED
  CHECK_SERVICE_INACTIVE
}

function DEACTIVATE_VNC_SERVICE {
  CHECK_SERVICE_ACTIVE
  CHECK_SERVICE_ENABLED
}

function REMOVE_VNC_SERVER_AND_SERVICE {
  DEACTIVATE_VNC_SERVICE
  systemctl daemon-reload
  REMOVE_FILES
  DONE
  MENU
}

function GREP_VARIABLES {  
  port=$(egrep "port" /etc/dispmanx_vncserver.conf | egrep -o [0-9]+)
  framerate=$(egrep "frame-rate" /etc/dispmanx_vncserver.conf | egrep -o [0-9]+)
  mypassword=$(egrep "password" /etc/dispmanx_vncserver.conf | cut -d'"' -f2)
}

function COPY_CONF {
  cd /home/osmc/dispmanx_vnc-master
  
  sudo cp dispmanx_vncserver.conf.sample /etc/dispmanx_vncserver.conf
  sed -i /etc/dispmanx_vncserver.conf -e 's/port =.*/port = 5900;/'
}

function COPY_BIN {
  REMOVE_BIN
  cd /home/osmc/dispmanx_vnc-master
  
  sudo cp dispmanx_vncserver /usr/bin
}

function SET_VARIABLES {
  sed -i /etc/dispmanx_vncserver.conf -e 's/port =.*/port = '"$port"';/'
  sed -i /etc/dispmanx_vncserver.conf -e 's/frame-rate =.*/frame-rate = '"$framerate"';/'
  sed -i /etc/dispmanx_vncserver.conf -e 's/password =.*/password = "'"$mypassword"'";/'
}

function APT_INSTALL {
  apt-get update 1> /dev/null
  apt-get install -y build-essential rbp-userland-dev-osmc libvncserver-dev libconfig++-dev unzip 1> /dev/null
}

function CLEANUP_INSTALL {
  cd /home/osmc/
  
  if [ -d "dispmanx_vnc-master/" ];
    then
      rm -rf dispmanx_vnc-master/
  fi
  
  if [ -e "master.zip" ];
    then
      rm -f master.zip
  fi
}

function REMOVE_FILES {
  REMOVE_CONF
  REMOVE_BIN
  REMOVE_SERVICE_FILE
}

function REMOVE_CONF {
  cd /etc

  if [ -e "dispmanx_vncserver.conf" ];
    then
      rm -f dispmanx_vncserver.conf
  fi
}

function REMOVE_BIN {
  cd /usr/bin

  if [ -e "dispmanx_vncserver" ];
    then
      rm -f dispmanx_vncserver
  fi
}

function REMOVE_SERVICE_FILE {
  cd /etc/systemd/system

  if [ -e "dispmanx_vncserver.service" ];
    then
      rm -f dispmanx_vncserver.service
  fi
}

function GET_DISPMANX {
  cd ~
  
  wget -q https://github.com/patrikolausson/dispmanx_vnc/archive/master.zip
  unzip -q -u master.zip -d  /home/osmc/
}

function MAKE_DISPMANX {
  cd /home/osmc/dispmanx_vnc-master
  
  # --quiet after make to make it silent
  make --quiet clean
  make --quiet
}

function CREATE_VNC_SERVER {
  GET_DISPMANX
  MAKE_DISPMANX
  COPY_BIN
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
  #echo $1
  # Store data to $VALUES variable
  VALUES=$(dialog --title "" \
         --stdout \
         --backtitle "Installing VNC-Server on OSMC" \
         --insecure \
		 --ok-label Set \
		 $1 \
         --output-separator $separator \
         --mixedform "Configuration" \
         10 50 0 \
        "Port:   (eg. 5900)" 1 2 "$port"        1 21 12 0 0 \
        "Framerate: (10-25)" 2 2 "$framerate"   2 21 12 0 0 \
        "VNC-Password:"      3 2 "$mypassword"  3 21 12 0 1 \
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
   0)   SET_VARIABLES
        DONE
        MENU
        ;;
   1)   MENU
        ;;
   255) MENU
        ;;
  esac
}

function MENU { 
  # Store data to $VALUES variable
  VALUE=$(dialog --backtitle "Installing VNC-Server on OSMC" \
         --title "" \
         --stdout \
         --no-tags \
         --cancel-label "Quit" \
         --menu "Choose a Option" 17 57 9 \
         "1" "OSMC System-Update" \
         "2" "Install VNC Server and Service" \
		 "3" "Remove VNC Server and Service" \
         "4" "Update VNC Server (mandatory after a kernel update)" \
         "5" "Change VNC Configuration" \
         "6" "Start VNC (manual, not Service)" \
         "7" "Stop VNC (manual, not Service)" \
         "8" "Activate VNC Service" \
         "9" "Deactivate VNC Service"
  )
  response=$?
  
  # display values just entered
  #echo "$response"
  #echo "$VALUE"
  
  case $response in
   0)   OPTIONS
        ;;
   1)   EXIT
        ;;
   255) EXIT
        ;;
  esac
}

CHECK_ROOT
MENU