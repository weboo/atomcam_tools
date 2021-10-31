#!/bin/sh
#
# for alarm record file
#

[ "$1" != "" ] && [ -e $1 ] && FILE=$1
[ "$2" != "" ] && [ -e $2 ] && FILE=$2
if [ "$FILE" != "/tmp/alarm.jpg" ] && [ "$FILE" != "/tmp/alarm_record.mp4" ] ; then
  /bin/busybox ${0##*/} $*
  exit
fi

HACK_INI=/media/mmc/hack.ini
RECORDING_ALARM=$(awk -F "=" '/RECORDING_ALARM *=/ {print $2}' $HACK_INI)
STORAGE_SDCARD=$(awk -F "=" '/STORAGE_SDCARD *=/ {print $2}' $HACK_INI)
STORAGE_CIFS=$(awk -F "=" '/STORAGE_CIFS *=/ {print $2}' $HACK_INI)
STORAGE_CIFSSERVER=$(awk -F "=" '/STORAGE_CIFSSERVER *=/ {print $2}' $HACK_INI)
STORAGE_CIFSUSER=$(awk -F "=" '/STORAGE_CIFSUSER *=/ {print $2}' $HACK_INI)
STORAGE_CIFSPASSWD=$(awk -F "=" '/STORAGE_CIFSPASSWD *=/ {print $2}' $HACK_INI)
WEBHOOK_URL=$(awk -F "=" '/WEBHOOK_URL *=/ {print $2}' $HACK_INI)
WEBHOOK_ALERM_PICT=$(awk -F "=" '/WEBHOOK_ALERM_PICT *=/ {print $2}' $HACK_INI)
WEBHOOK_ALERM_VIDEO=$(awk -F "=" '/WEBHOOK_ALERM_VIDEO *=/ {print $2}' $HACK_INI)
HOSTNAME=`hostname`

USER_CONFIG=/atom/configs/.user_config
ALARM_CONFIG=/atom/configs/.multiplealarm_config
ALARMDATE=$(awk -F "=" '/alarmDate *=/ {print $2}' $USER_CONFIG)
if [ "$ALARMDATE" = "0" ] && [ -f $ALARM_CONFIG ]; then
  FMT=`TZ=JST-9 awk '
    BEGIN {
      FS = "=";
      INDEX=-1;
    }
    /\[index_/ {
      INDEX = $0;
      gsub(/^.*_/, "", INDEX);
      gsub(/\].*$/, "", INDEX);
      INDEX = INDEX + 0;
      ENABLE[INDEX] = 1;
    }
    /Rule=/ {
      day = strftime("%w");
      dayMask = $2;
      if(day == 0) day = 7;
      for(i = 0; i < day; i++) {
        dayMask = int(dayMask / 2);
      }
      if(dayMask % 2 == 0) ENABLE[INDEX] = 0;
    }
    /ContinueTime=/ {
      CONTINUETIME[INDEX] = $2;
    }
    /StartTime=/ {
      STARTTIME[INDEX] = $2;
    }
    /Status=/ {
      if($2 != 1) ENABLE[INDEX] = 0;
    }
    /DelFlags=/ {
      if($2 != 1) ENABLE[INDEX] = 0;
    }
    END {
      HOUR = strftime("%H");
      MINUTE = strftime("%M");
      NOW = HOUR * 60 + MINUTE;
      FLAG = 0;
      for(i = 1; i <= INDEX; i++) {
        if(NOW < STARTTIME[i]) ENABLE[i] = 0;
        if(NOW >= STARTTIME[i] + CONTINUETIME[i]) ENABLE[i] = 0;
        if(ENABLE[i]) FLAG = 1;
      }
      if(FLAG) print strftime("%Y%m%d_%H%M%S");
    }
  ' ALARMDATE=$ALARMDATE $ALARM_CONFIG`
else
  FMT=`TZ=JST-9 date +"%Y%m%d_%H%M%S"`
fi

if [ "$WEBHOOK" = "on" ] && [ "$WEBHOOK_URL" != "" ]; then
  if [ "$WEBHOOK_ALERM_PICT" = "on" ] && [ "$FILE" = "/tmp/alarm.jpg" ]; then
     LD_LIBRARY_PATH=/tmp/system/lib:/usr/lib /tmp/system/lib/ld.so.1 /tmp/system/bin/curl -X POST -F "image=@$FILE;type=image/jpeg" $WEBHOOK_URL
  fi
  if [ "$WEBHOOK_ALERM_VIDEO" = "on" ] && [ "$FILE" = "/tmp/alarm_record.mp4" ]; then
     LD_LIBRARY_PATH=/tmp/system/lib:/usr/lib /tmp/system/lib/ld.so.1 /tmp/system/bin/curl -X POST -F "video=@$FILE;type=video/mp4" $WEBHOOK_URL
  fi
fi

if [ "$FMT" != "" ] && [ "$RECORDING_ALARM" = "on" ]; then
  if [ "$STORAGE_CIFS" = "on" ] && [ "$STORAGE_CIFSSERVER" != "" ]; then
    if ! mount | grep "$STORAGE_CIFSSERVER" > /dev/null ; then
      LD_LIBRARY_PATH=/tmp/system/lib:/usr/lib:/usr/lib/samba /tmp/system/lib/ld.so.1 /tmp/system/bin/busybox mount -t cifs -ousername=$STORAGE_CIFSUSER,password=$STORAGE_CIFSPASSWD $STORAGE_CIFSSERVER /mnt
    fi
    if [ $? = 0 ]; then
      OUTFILE=/mnt/$HOSTNAME/alarm_record/$FMT.mp4
      DIR_PATH=${OUTFILE%/*}
      mkdir -p $DIR_PATH
      cp $FILE $OUTFILE
    fi
  fi

  if [ "$STORAGE_SDCARD" = "on" ]; then
    OUTFILE=/media/mmc/alarm_record/$FMT.mp4
    DIR_PATH=${OUTFILE%/*}
    mkdir -p $DIR_PATH
    /bin/busybox mv $FILE $OUTFILE
  else
    /bin/busybox rm $FILE
  fi
else
  /bin/busybox rm $FILE
fi