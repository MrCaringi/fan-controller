#!/bin/bash

###############################
    #           IPMI Fan Controller V1.2
    #
    ##  HOW TO USE
    #	    sudo bash ipmi-fan-R320.sh /path/to/ipmi-fan-R320.json
    #
    ##	PARAMETERS
    #	    1 $REP_DIR     configuration file path 
    # 
    ##	MODIFICATION LOG
    #		2020-10-23  First version
    #       2020-10-24  Improving fan speed logic when temp is below target
    #
    ##  REQUIREMENTS
    #       Packages:
    #       jq  lightweight and flexible command-line JSON processor
    #       ipmitool    utility for IPMI control with kernel driver or LAN interface (daemon)
    #
    ###############################

##      Getting the Configuration
#   IPMI 
    Host_IPMI=$(cat $1 | jq --raw-output '.IPMI_config.Host_IPMI')
    User_IPMI=$(cat $1 | jq --raw-output '.IPMI_config.User_IPMI')
    Passw_IPMI=$(cat $1 | jq --raw-output '.IPMI_config.Passw_IPMI')
    EncKey_IPMI=$(cat $1 | jq --raw-output '.IPMI_config.EncKey_IPMI')

#   Program
    Interval=$(cat $1 | jq --raw-output '.Program_config.Interval')
    Max_CPU_Temp=$(cat $1 | jq --raw-output '.Program_config.Max_CPU_Temp')
    Target_Temp=$(cat $1 | jq --raw-output '.Program_config.Target_Temp')
    Hist=$(cat $1 | jq --raw-output '.Program_config.Hist')
    Steps=$(cat $1 | jq --raw-output '.Program_config.Steps')
    MIN_hex=$(cat $1 | jq --raw-output '.Program_config.MIN_hex')
    MAX_hex=$(cat $1 | jq --raw-output '.Program_config.MAX_hex')
    INITIAL_hex=$(cat $1 | jq --raw-output '.Program_config.INITIAL_hex')
 
#   Notification
    SendMessage=$(cat $1 | jq --raw-output '.Telegram.SendMessage')
    SendFile=$(cat $1 | jq --raw-output '.Telegram.SendFile')

##  Clearing Variables
    echo $(date +%Y%m%d-%H%M%S)" INFO: Clearing Variables"
    exit=0
    CPU_T_new=0
    CPU_T_old=0
    SPEED_hex_new=$(printf "0x%X\n" 0x00)
    SPEED_hex_old=$(printf "0x%X\n" 0x00)
    Steps=$(printf "0x%X\n" $Steps)
    INITIAL_hex=$(printf "0x%X\n" $INITIAL_hex)
    

# -------------------------------------------------------------------------------
# First Check
# -------------------------------------------------------------------------------
    echo $(date +%Y%m%d-%H%M%S)" INFO: First Run"
    CPU_T_new=$(ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI sdr type temperature |grep -e "0Eh" -e "0Fh" |grep -Po '\d{2}')
    echo $(date +%Y%m%d-%H%M%S)" INFO: Actual CPU Temp: "$CPU_T_new

    if [ $CPU_T_new -gt $Max_CPU_Temp ]; then
        echo $(date +%Y%m%d-%H%M%S)" WARNING: CPU Temp is greater than expected ( "$Max_CPU_Temp" ), Turning ON AUTOMATIC IDRAC FAN CONTROL"
        ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI raw 0x30 0x30 0x01 0x01
        
        else
            echo $(date +%Y%m%d-%H%M%S)" INFO: CPU Temp is below limit ( "$Max_CPU_Temp" ), Turning OFF AUTOMATIC IDRAC FAN CONTROL"
            ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI raw 0x30 0x30 0x01 0x00
            echo $(date +%Y%m%d-%H%M%S)" INFO: Changin to Default Fan Speed ( "$INITIAL_hex ")"
            ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI raw 0x30 0x30 0x02 0xff $INITIAL_hex
        
    fi
    CPU_T_old=$CPU_T_new
    SPEED_hex_old=$(printf "0x%X\n" $INITIAL_hex)

# -------------------------------------------------------------------------------
# The Magic Starts Here
# -------------------------------------------------------------------------------
    echo $(date +%Y%m%d-%H%M%S)" INFO: Entering to The Loop"
    while [ $exit -eq 0 ]
    do
        CPU_T_new=$(ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI sdr type temperature |grep -e "0Eh" -e "0Fh" |grep -Po '\d{2}')
        #echo $(date +%Y%m%d-%H%M%S)" INFO: New Temp: "$CPU_T_new
        
        ##  Verifiying if CPU Temp is higher than expected
            if [ $CPU_T_new -gt $Target_Temp ]; then
                echo $(date +%Y%m%d-%H%M%S)" INFO: New Temp ( "$CPU_T_new" ), is greater than expected ( "$Target_Temp" )" 
                #   Checking if the speed should be increased
                    if [ $CPU_T_old -gt $CPU_T_new ]; then
                        #   CPU getting cooler, do nothing
                        echo $(date +%Y%m%d-%H%M%S)" INFO: Old Temp ( "$CPU_T_old" ), is greater than New Temp ( "$CPU_T_new" ); Temp is decreasing, Speed ( "$SPEED_hex_old" ) is kept."
                    else
                        #   CPU is not getting cooler, speeding up
                        SPEED_hex_new=$(( $SPEED_hex_old + $Steps ))
                        SPEED_hex_new=$(printf "0x%X\n" $SPEED_hex_new)
                        echo $(date +%Y%m%d-%H%M%S)" WARNING: Temp is not decreasing, speeding up the fan to: "$SPEED_hex_new
                        ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI raw 0x30 0x30 0x02 0xff $SPEED_hex_new
                    fi    
            else
            ##  Verifiying if CPU Temp is equal to expected
                if [ $CPU_T_new -eq $Target_Temp ]; then
                    #   Temp is OK
                    echo $(date +%Y%m%d-%H%M%S)" INFO: New Temp ( "$CPU_T_new" ), is the expected ( "$Target_Temp" ), doing nothing."
                else
                    ##   Temp is below expected
                    #   Checking if the speed should be decreased
                    if [ $CPU_T_new -gt $CPU_T_old ]; then
                        #   CPU getting hotter, do nothing
                        echo $(date +%Y%m%d-%H%M%S)" INFO: Old Temp ( "$CPU_T_old" ), is lower than New Temp ( "$CPU_T_new" ); Temp is increasing, Speed ( "$SPEED_hex_old" ) is kept."
                    else
                        #   CPU is getting cooler, speeding down
                        SSPEED_hex_new=$(( $SPEED_hex_old - $Steps ))
                        SPEED_hex_new=$(printf "0x%X\n" $SPEED_hex_new)
                        echo $(date +%Y%m%d-%H%M%S)" WARNING: Temp is getting cooler, speeding down the fan to: "$SPEED_hex_new
                        ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI raw 0x30 0x30 0x02 0xff $SPEED_hex_new
                    fi
                fi
            fi
        #   Updating OLD Values
            CPU_T_old=$CPU_T_new
            SPEED_hex_old=$(printf "0x%X\n" $SPEED_hex_new)
        echo "-------------------- loop --------------------"
        sleep $Interval
        #exit=1
    done
    echo $(date +%Y%m%d-%H%M%S)" INFO: Exit"
exit 0