#!/bin/bash
# Set UTF-8; e.g. "en_US.UTF-8" or "de_DE.UTF-8":
#export LANG="C.UTF-8"
export LC_ALL="C.UTF-8"

# Tell ncurses to use line characters that work with UTF-8.
export NCURSES_NO_UTF8_ACS=1

separator=":"

port="5900"
framerate="23"
mypassword=""

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
    3) echo "$VALUE";;
    4) echo "$VALUE";;
    5) echo "$VALUE";;
    6) echo "$VALUE";;
    7) echo "$VALUE";;
    8) echo "$VALUE";;
	9) echo "$VALUE";;
  esac
}

function APT-UPDATE {
  apt-get update 1> /dev/null
}

function APT-DISTUPGRADE {
  apt-get -y dist-upgrade
  apt-get autoremove
}

function ONE {
  APT-UPDATE
  APT-DISTUPGRADE
  DONE
  sleep 1
  MENU
}

function DONE {
  dialog --backtitle "Installing VNC-Server on OSMC" \
         --infobox "Done" \
         5 20
}

function TWO {
  CONFS
}

function TWO_PARTS {
  DONE
  sleep 1
  MENU
}

function CONFS {
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
  
  echo "$port"
  echo "$framerate"
  echo "$mypassword"
  
  case $rep in
   0) TWO_PARTS;;
   1) MENU;;
   255) MENU;;
  esac
}

function MENU {
  port="5900"
  framerate="23"
  mypassword=""
  
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