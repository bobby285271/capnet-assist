#!/bin/bash
#/etc/NetworkManager/dispatcher.d/90captive_portal_test
INTERFACE=$1
STATUS=$2

wait_for_process() {
  PNAME=$1
  PID=`/usr/bin/pgrep $PNAME`
  while [ -z "$PID" ]; do
        sleep 3;
        PID=`/usr/bin/pgrep $PNAME`
  done
}

#launch the browser, but on boot we need to wait that nm-applet starts
start_browser() {
     wait_for_process nm-applet
     logger -s "Running browser as '$user' to login in captive portal"
     su $user -c "sensible-browser www.elementaryos.org"
}

case "$2" in
    up)
    #set the DISPLAY where to show the browser
    if [ -z $DISPLAY ];then
        export DISPLAY=':0'
    fi
    
    logger -s "DetectCaptivePortal script triggered"
    
    #get the username
    user=$(who | grep "$DISPLAY" | awk '{print $1}' | tail -n1)
    #get HTTP response from google, should always return 204...
    res=$(curl -sL -w "%{http_code}\\n" "http://clients3.google.com/generate_204" -o /dev/null)
    logger -s "HTTP response is: $res"
    
    #... so when it returns something different than 204 we have a walled garden (HTTP request redirected to login page)
    if [ $res = 204 ]
    then	
        logger -s "Connection already established"
    else
        logger -s "HTTP response should be 204. We are in a walled garden"
        start_browser
    fi
    ;;
    *)
    ;;
esac