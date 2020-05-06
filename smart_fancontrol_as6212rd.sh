#!/bin/sh

###############################
#  SMART FAN CONTROL for AS6212RD
#
#	sh smart_fancontrol_as6212rd.sh -v
#
#	PARAMETERS
#	1 $verbose - Verbose mode
#
#       CONSIDERATIONS
#       Excecute it with root/sudo permissions
#
#	MODIFICATION LOG
#		2020-05-04  First version
#		2020-05-  Uploaded a GitHub version
#
#
###############################

if [ "$1" = "-v" ]
then
        VERBOSE=1
fi

##      Commented: this script will force speed on both fans
#FANID=0
DEF_DESIREDPOWER=75 # from about 30 to 255
CYCLETEMPCHECK=18 # every how many 10" cycles we check for temp changes. 6 = every mn
#
##      Configuration file, in order to make changes more easily 
#       temperature to power grid : GRIDxx=yy : we want power of yy if temp is xx

. /home/jfc/scripts/smart-fan.conf

#
# let's learn devices which have temperature sensors
#
HOTTESTDISKTEMP=15
LSTDEVICES=""
for DSKDEV in /dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg
do
        df | grep $DSKDEV | grep USB >/dev/null 2>&1
        if [ $? -ne 0 ]
                then
                TSTTEMP=`/volume0/usr/builtin/sbin/smartctl a -d sat $DSKDEV|awk '/^194/ { print $10 } '`
                #       Find out where you "smartctl" bin is located with "sudo find / -iname smartctl"
                # /volume0/usr/builtin/sbin/smartctl -a -d sat /dev/sda
                if [ "$TSTTEMP" != "" ]
                then
                        if [ \( "$TSTTEMP" -gt 15 \) -a \( "$TSTTEMP" -lt 70 \) ]
                        then
                                [ $VERBOSE ] && echo $DSKDEV added to list with recognized temp of $TSTTEMP
                                LSTDEVICES="$LSTDEVICES $DSKDEV"
                        fi
                fi
        fi
done
[ $VERBOSE ] && echo Retained devices for temperature check : $LSTDEVICES

# DESIREDPOWER=$DEF_DESIREDPOWER # from about 30 to 255
DESIREDPOWER=`fanctrl -getfanspeed|awk ' { print $NF } '`
COUNTDWN=0
CPT=0
DELAY=1 # initial loop = no delay

while :
do
#
# temperature check
#
        if [ $COUNTDWN -le 0 ]
        then
                COUNTDWN=$CYCLETEMPCHECK
                # we almost cancel pause because this loop consumes time.
                DELAY=1
                NEW_HOTTESTDISKTEMP=15
                for DSKDEV in $LSTDEVICES
                do
                        TSTTEMP=`/volume0/usr/builtin/sbin/smartctl a -d sat $DSKDEV|awk '/^194/ { print $10 } '`
                        if [ "$TSTTEMP" -gt $NEW_HOTTESTDISKTEMP ]
                        then
                                NEW_HOTTESTDISKTEMP=$TSTTEMP
                        fi
                done
                NEW_DESIREDPOWER=`eval echo \\\$GRID$NEW_HOTTESTDISKTEMP`
                if [ "$NEW_DESIREDPOWER" = "" ]
                then
                        NEW_DESIREDPOWER=$DEF_DESIREDPOWER
                fi
                if [ $HOTTESTDISKTEMP != $NEW_HOTTESTDISKTEMP ]
                then
                        if [ $DESIREDPOWER != $NEW_DESIREDPOWER ]
                        then
                                [ $VERBOSE ] && echo `date +%Y%m%d_%T` hottest disk changed from $HOTTESTDISKTEMP to $NEW_HOTTESTDISKTEMP,raising fanpower from $DESIREDPOWER to $NEW_DESIREDPOWER
                                DESIREDPOWER=$NEW_DESIREDPOWER
                        else
                                [ $VERBOSE ] && echo `date +%Y%m%d_%T` hottest disk changed from $HOTTESTDISKTEMP to $NEW_HOTTESTDISKTEMP,fanpower leaved unchanged at $DESIREDPOWER
                        fi
                        HOTTESTDISKTEMP=$NEW_HOTTESTDISKTEMP
                ## else
                        ## [ $VERBOSE ] && echo `date +%Y%m%d_%T` hottest disk leaved unchanged at $HOTTESTDISKTEMP ,fanpower leaved unchanged at $DESIREDPOWER
                fi
        fi

#
# fan override loop
#
        CURRPOWER=`fanctrl -getfanspeed|awk ' { print $NF } ' `
        if [ $DESIREDPOWER -ne $CURRPOWER ]
        then
                fanctrl -setfanpwm 0 $DESIREDPOWER
                fanctrl -setfanpwm 1 $DESIREDPOWER
                ## echo $CURRPOWER to $DESIREDPOWER CPT : $CPT
                CPT=0
                COUNTDWN=`expr $COUNTDWN - 1`
                sleep $DELAY
                DELAY=9
        else
                sleep 0.1
                CPT=`expr $CPT + 1`
        fi
done