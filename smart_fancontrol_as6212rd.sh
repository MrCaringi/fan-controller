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
#		2020-05-06  Uploaded a GitHub version
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

GRID15=30
GRID16=30
GRID17=30
GRID18=31
GRID19=33
GRID20=35
GRID21=37
GRID22=39
GRID23=41
GRID24=44
GRID25=47
GRID26=50
GRID27=54
GRID28=59
GRID29=65
GRID30=68
GRID31=70
GRID32=72
GRID33=74
GRID34=75
GRID35=77
GRID36=79
GRID37=82
GRID38=84
GRID39=85
GRID40=90
GRID41=95
GRID42=96
GRID43=97
GRID44=98
GRID45=110
GRID46=115
GRID47=120
GRID48=125
GRID49=130
GRID50=135
GRID51=140
GRID52=145
GRID53=150
GRID54=160
GRID55=170
GRID56=180
GRID57=190
GRID58=210
GRID59=230
GRID60=250
GRID61=250
GRID62=250
GRID63=250
GRID64=250

#
# let's learn devices which have temperature sensors
#
HOTTESTDISKTEMP=15
LSTDEVICES=""
for DSKDEV in /dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf
do
        TSTTEMP=`/volume0/usr/builtin/sbin/smartctl -a -d sat $DSKDEV|awk '/^194/ { print $10 } '`
        [ $VERBOSE ] && echo $DSKDEV added to list with recognized temp of $TSTTEMP
        LSTDEVICES="$LSTDEVICES $DSKDEV"
done
[ $VERBOSE ] && echo Retained devices for temperature check : $LSTDEVICES

# DESIREDPOWER=$DEF_DESIREDPOWER # from about 30 to 255
DESIREDPOWER=`fanctrl -getfanspeed|awk ' { if(NR>1)print $NF } '`
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
                        TSTTEMP=`/volume0/usr/builtin/sbin/smartctl -a -d sat $DSKDEV|awk '/^194/ { print $10 } '`
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
                                [ $VERBOSE ] && echo `date +%Y%m%d_%T` hottest disk changed from $HOTTESTDISKTEMP to $NEW_HOTTESTDISKTEMP, changing fanpower from $DESIREDPOWER to $NEW_DESIREDPOWER
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

        CURRPOWER=`fanctrl -getfanspeed|awk ' { if(NR>1)print $NF } '`
        if [ $DESIREDPOWER -ne $CURRPOWER ]
        then
                fanctrl -setfanpwm 0 $DESIREDPOWER
                fanctrl -setfanpwm 1 $DESIREDPOWER
                sleep 1
                echo `fanctrl -getfanspeed`
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