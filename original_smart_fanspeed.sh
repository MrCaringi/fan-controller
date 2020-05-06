#!/bin/sh

## Taken from
# https://forum.asustor.com/viewtopic.php?f=97&t=8948&p=28478#p28478

if [ "$1" = "-v" ]
then
        VERBOSE=1
fi

FANID=0
DEF_DESIREDPOWER=75 # from about 30 to 255
CYCLETEMPCHECK=18 # every how many 10" cycles we check for temp changes. 6 = every mn
#
# temperature to power grid : GRIDxx=yy : we want power of yy if temp is xx
GRID15=30 ; GRID16=30 ; GRID17=30 ; GRID18=31 ; GRID19=33
GRID20=35 ; GRID21=37 ; GRID22=39 ; GRID23=41 ; GRID24=44
GRID25=47 ; GRID26=50 ; GRID27=54 ; GRID28=59 ; GRID29=65
GRID30=68 ; GRID31=70 ; GRID32=72 ; GRID33=74 ; GRID34=75
GRID35=77 ; GRID36=79 ; GRID37=82 ; GRID38=84 ; GRID39=85
GRID40=86 ; GRID41=88 ; GRID42=90 ; GRID43=92 ; GRID44=94
GRID45=96 ; GRID46=98 ; GRID47=99 ; GRID48=100 ; GRID49=110
GRID50=120 ; GRID51=130 ; GRID52=140 ; GRID53=150 ; GRID54=160
GRID55=170 ; GRID56=180 ; GRID57=190 ; GRID58=210 ; GRID59=230
GRID60=250 ; GRID61=250 ; GRID62=250 ; GRID63=250 ; GRID64=250



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
                TSTTEMP=`smartctl --all $DSKDEV|awk '/^194/ { print $10 } '`
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
                        TSTTEMP=`smartctl --all $DSKDEV|awk '/^194/ { print $10 } '`
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
                fanctrl -setfanpwm $FANID $DESIREDPOWER
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