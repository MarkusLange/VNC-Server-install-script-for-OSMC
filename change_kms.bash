#!/bin/bash

function CHANGE_KMS_TO_KKMS {
  #Name: vc4-fkms-v3d
  #Info: Enable Eric Anholt's DRM VC4 V3D driver on top of the dispmanx
  #display stack.

  if grep -q 'dtoverlay=vc4-kms' '/boot/config.txt';
  then
    echo "Found"
    sed -i /boot/config.txt -e 's/vc4-kms-v3d/vc4-fkms-v3d/'
  else
    echo "Not found"
  fi
}

function CHANGE_FKMS_TO_KMS {
  #Name: vc4-kms-v3d
  #Info: Enable Eric Anholt's DRM VC4 HDMI/HVS/V3D driver.

  if grep -q 'dtoverlay=vc4-fkms' '/boot/config.txt';
  then
    echo "Found"
    sed -i /boot/config.txt -e 's/vc4-fkms-v3d/vc4-kms-v3d/'
  else
    echo "Not found"
  fi
}

CHANGE_KMS_TO_KKMS
CHANGE_FKMS_TO_KMS
