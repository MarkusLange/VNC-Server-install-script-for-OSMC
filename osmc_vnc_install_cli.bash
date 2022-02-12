#!/bin/bash
# Set UTF-8; e.g. "en_US.UTF-8" or "de_DE.UTF-8":
#export LANG="C.UTF-8"
export LC_ALL="C.UTF-8"

# Tell ncurses to use line characters that work with UTF-8.
export NCURSES_NO_UTF8_ACS=1

NARGS=$#
VALUE=$1

port=$2
framerate=$3
mypassword=$4

separator=":"

function ROOT_CHECK {
  # check if root for future installations
  if [ "$(id -u)" != "0" ];
  then
    HELP
    exit 1
  else
    OPTIONS
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

function CHANGE_KMS_TO_FKMS {
  #Name: vc4-fkms-v3d
  #Info: Enable Eric Anholt's DRM VC4 V3D driver on top of the dispmanx display stack.
  if grep -q 'dtoverlay=vc4-kms' '/boot/config.txt';
  then
    sed -i /boot/config.txt -e 's/vc4-kms-v3d/vc4-fkms-v3d/'
	FORCED_REBOOT
  fi
}

function CHANGE_FKMS_TO_KMS {
  #Name: vc4-kms-v3d
  #Info: Enable Eric Anholt's DRM VC4 HDMI/HVS/V3D driver.
  if grep -q 'dtoverlay=vc4-fkms' '/boot/config.txt';
  then
    sed -i /boot/config.txt -e 's/vc4-fkms-v3d/vc4-kms-v3d/'
	FORCED_REBOOT
  fi
}

function CHANGE_AUDIO_TO_DTPARAM {
  #Change audio directing to dtparam since fKMS does not support audio trough HMDI by default
  if [ -e "/boot/config-user.txt" ];
  then
    if grep -q '[all]' '/boot/config-user.txt';
    then
	  :
	else
      echo [all] >> /boot/config-user.txt
    fi
    
    if grep -q '#dtparam=audio=on' '/boot/config-user.txt';
    then
      sed -i /boot/config-user.txt -e 's/#dtparam=audio=on/dtparam=audio=on/'
    else
	  if grep -q 'dtparam=audio=on' '/boot/config-user.txt';
      then
	    :
	  else
        sed -i '/[all]/a dtparam=audio=on' /boot/config-user.txt
	  fi
    fi
  fi
}

function CHANGE_AUDIO_TO_CV4 {
  #Change audio directing to KMS support by vc4
  if [ -e "/boot/config-user.txt" ];
  then
    if grep -q 'dtparam=audio=on' '/boot/config-user.txt';
    then
      sed -i /boot/config-user.txt -e 's/dtparam=audio=on/#dtparam=audio=on/'
    fi
  fi
}

function AKTIVE_FKMS {
  CHANGE_AUDIO_TO_DTPARAM
  CHANGE_KMS_TO_FKMS
}

function AKTIVE_KMS {
  CHANGE_AUDIO_TO_CV4
  CHANGE_FKMS_TO_KMS
}

function APT_UPDATE {
  apt-get update 1> /dev/null
}

function APT_UPGRADE {
  apt-get -y dist-upgrade 1> /dev/null
}

function APT_CLEAN {
  apt-get -y autoclean 1> /dev/null
  apt-get -y autoremove 1> /dev/null
}

function OSMC_UPATE {
  echo "starting"
  APT_UPDATE
  APT_UPGRADE
  APT_CLEAN
  FORCED_REBOOT
}

function FORCED_REBOOT {
  #echo $NARGS
  if [ $NARGS -ne 1 ];
  then
    REBOOT_FOLLOWS
  fi
  sleep 0.5
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
  sleep 0.5
}

function EXIT {
  dialog --backtitle "Installing VNC-Server on OSMC" \
         --infobox "Exit" \
         5 20
  sleep 0.5
  clear
}

function INSTALL_VNC {
  INSTALL_VNC_SERVER_AND_SERVICE
  if [ $NARGS -ne 1 ];
  then
    CHANGE_VNC_SETTINGS --nocancel
  else
	SET_VARIABLES
  fi
  AKTIVE_FKMS
}

function REMOVE_VNC {
  REMOVE_VNC_SERVER_AND_SERVICE
  AKTIVE_KMS
  if [ $NARGS -ne 1 ];
  then
    DONE
    MENU
  fi
}

function UPDATE_VNC {
  UPDATE_VNC_SERVER
  if [ $NARGS -ne 1 ];
  then
    DONE
    MENU
  fi
  CHANGE_KMS_TO_FKMS
}

function INSTALL_VNC_SERVER_AND_SERVICE {
  echo -n "starting"
  APT_UPDATE
  APT_INSTALL
  CREATE_VNC_SERVER
  COPY_CONF
  CLEANUP_INSTALL
  CREATE_SERVICE_FILE
  systemctl daemon-reload
  ACTIVATE_VNC_SERVICE
}

function UPDATE_VNC_SERVER {
  echo -n "starting"
  APT_UPDATE
  DEACTIVATE_VNC_SERVICE
  CREATE_VNC_SERVER
  CLEANUP_INSTALL
  ACTIVATE_VNC_SERVICE
}

function CHANGE_VNC_SETTINGS() {
  GREP_VARIABLES
  CONFIG $1
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
  cd /home/osmc/
  
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
  menu_options=("1" "OSMC System-Update (with forced reboot)"
                "2" "Install VNC Server and Service"
                "3" "Remove VNC Server and Service"
                "4" "Update VNC Server (mandatory after a kernel update)"
                "5" "Change VNC Configuration"
                "6" "Start VNC (manual, not Service)"
                "7" "Stop VNC (manual, not Service)"
                "8" "Activate VNC Service"
                "9" "Deactivate VNC Service")
  
  if grep -q 'dtoverlay=vc4' '/boot/config.txt';
  then
    menu_options+=("A" "Activate fake-KMS driver"
                   "B" "Activate KMS driver (mandatory update)")
  fi
  
  # Store data to $VALUES variable
  VALUE=$(dialog --backtitle "Installing VNC-Server on OSMC" \
         --title "" \
         --stdout \
         --no-tags \
         --cancel-label "Quit" \
         --menu "Choose a Option" 17 57 9 "${menu_options[@]}"
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

function HELP {
  echo "This script has to run as root: sudo $0"
  echo
  echo "You can start this script as GUI without parameter, or by using the"
  echo "following parameter to run it in CLI-Mode:"
  echo
  echo "--system-update,      updates OSMC and the system (with forced reboot)"
  echo "--install-vnc,        install VNC with three additional parameter needed port,"
  echo "                      framerate and password"
  echo "                      e.g. --install-vnc 5900 25 osmc"
  echo "--remove-vnc,         removes all files from VNC"
  echo "--update-vnc,         recompile VNC after an OSMC update"
  echo "--change-config,      changes the config with three additional parameter needed"
  echo "                      port, framerate and password"
  echo "                      e.g. --change-config 5900 25 osmc"
  echo "--start-vnc,          start VNC-Server"
  echo "--stop-vnc,           stop VNC-Server"
  echo "--activate-service,   activate VNC as service"
  echo "--deactivate-service, deactivate VNC as service"
  
  if grep -q 'dtoverlay=vc4' '/boot/config.txt';
  then
    echo "--change-to-fkms,     change to fake-KMS driver"
    echo "--change-to-kms,      change to KMS driver (mandatory update)"
  fi
  
  echo "--help,               this!"
  echo
}

function OPTIONS {
  case $VALUE in
    1|--system-update)      OSMC_UPATE;;
    2|--install-vnc)        INSTALL_VNC;;
    3|--remove-vnc)         REMOVE_VNC;;
    4|--update-vnc)         UPDATE_VNC;;
    5|--change-config)      SET_VARIABLES;;
    6|--start-vnc)          START_VNC;;
    7|--stop-vnc)           STOP_VNC;;
    8|--activate-service)   ACTIVATE_VNC_SERVICE;;
    9|--deactivate-service) DEACTIVATE_VNC_SERVICE;;
    A|--change-to-fkms)     CHANGE_KMS_TO_FKMS;;
    B|--change-to-kms)      CHANGE_FKMS_TO_KMS;;
    --clean-up)             CLEANUP_INSTALL;;
    --help)                 HELP;;
    *)                      MENU;;
  esac
}

ROOT_CHECK