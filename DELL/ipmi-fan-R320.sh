#!/bin/bash

###############################
    #           IPMI Fan Controller V1.3
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
    #       2020-10-28  V1.3    Fine tuning when running, Improved fan control with "jumps" speed change
    #       2020-10-29  V1.3.1  Managing odd values when the environment temp is to low
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
    JumpTemp=$(cat $1 | jq --raw-output '.Program_config.JumpTemp')
    Hist=$(cat $1 | jq --raw-output '.Program_config.Hist')
    Steps=$(cat $1 | jq --raw-output '.Program_config.Steps')
    Jump=$(cat $1 | jq --raw-output '.Program_config.Jump')
    MIN_hex=$(cat $1 | jq --raw-output '.Program_config.MIN_hex')
    MAX_hex=$(cat $1 | jq --raw-output '.Program_config.MAX_hex')
    INITIAL_hex=$(cat $1 | jq --raw-output '.Program_config.INITIAL_hex')
 
#   Notification
    SendMessage=$(cat $1 | jq --raw-output '.Telegram.SendMessage')
    SendFile=$(cat $1 | jq --raw-output '.Telegram.SendFile')

##  Clearing Variables
    echo $(date +%Y%m%d-%H%M%S)" INFO: Clearing Variables"
    loop=0
    exit=0
    diff=0
    CPU_T_new=0
    CPU_T_old=0
    SPEED_hex_new=$(printf "0x%X\n" 0x0)
    SPEED_hex_old=$(printf "0x%X\n" 0x0)
    Steps=$(printf "0x%X\n" $Steps)
    Jump=$(printf "0x%X\n" $Jump)
    INITIAL_hex=$(printf "0x%X\n" $INITIAL_hex)
    MIN_hex=$(printf "0x%X\n" $MIN_hex)
    MAX_hex=$(printf "0x%X\n" $MAX_hex)

# -------------------------------------------------------------------------------
# First Check
# -------------------------------------------------------------------------------
    echo $(date +%Y%m%d-%H%M%S)" INFO: First Run"
    CPU_T_new=$(ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI sdr type temperature |grep -e "0Eh" -e "0Fh" |grep -Po '\d{2}')
    echo $(date +%Y%m%d-%H%M%S)" INFO: Actual CPU Temp: "$CPU_T_new

    if [ $CPU_T_new -gt $Max_CPU_Temp ]; then
        echo $(date +%Y%m%d-%H%M%S)" WARNING: CPU Temp is greater than expected ( "$Max_CPU_Temp" ), Turning ON AUTOMATIC IDRAC FAN CONTROL"
        ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI raw 0x30 0x30 0x01 0x01 >/dev/null 2>&1
        
        else
            echo $(date +%Y%m%d-%H%M%S)" INFO: CPU Temp is below limit ( "$Max_CPU_Temp" ), Turning OFF AUTOMATIC IDRAC FAN CONTROL"
            ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI raw 0x30 0x30 0x01 0x00 >/dev/null 2>&1
            echo $(date +%Y%m%d-%H%M%S)" INFO: Changin to Default Fan Speed ( "$INITIAL_hex ")"
            ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI raw 0x30 0x30 0x02 0xff $INITIAL_hex >/dev/null 2>&1
        
    fi
    #   Preparing data for first loop
        CPU_T_old=$CPU_T_new
        SPEED_hex_old=$(printf "0x%X\n" $INITIAL_hex)
        SPEED_hex_new=$(printf "0x%X\n" $INITIAL_hex)

# -------------------------------------------------------------------------------
# The Magic Starts Here
# -------------------------------------------------------------------------------
    echo $(date +%Y%m%d-%H%M%S)" INFO: Entering to The Loop"
    while [ $exit -eq 0 ]
    do
        CPU_T_new=$(ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI sdr type temperature |grep -e "0Eh" -e "0Fh" |grep -Po '\d{2}')
        #   Handling odd values; shit happends
            if [[ $SPEED_hex_old -lt $MIN_hex ]]; then
                SPEED_hex_old=$(( $MIN_hex + $Jump ))
                SPEED_hex_old=$(printf "0x%X\n" $SPEED_hex_old)
                echo $(date +%Y%m%d-%H%M%S)" WARNING: SPEED_hex_old has odd value, setting the minimal Speed + Jump = ( "$SPEED_hex_old" )"              
            fi
            if [[ $SPEED_hex_old -gt $MAX_hex ]]; then
                echo $(date +%Y%m%d-%H%M%S)" WARNING: SPEED_hex_old ( "$SPEED_hex_old" ) has odd value, setting the Initial Speed"
                SPEED_hex_old=$(printf "0x%X\n" $INITIAL_hex)
            fi
        
        ##  Verifiying if CPU Temp is higher than expected
            if [ $CPU_T_new -gt $Target_Temp ]; then
                echo $(date +%Y%m%d-%H%M%S)" INFO: New Temp ( "$CPU_T_new" ), is greater than expected ( "$Target_Temp" )" 
                #   Checking if the speed should be increased
                    if [ $CPU_T_old -gt $CPU_T_new ]; then
                        #   CPU getting cooler, do nothing
                        echo $(date +%Y%m%d-%H%M%S)" INFO: Old Temp ( "$CPU_T_old" ), is greater than New Temp ( "$CPU_T_new" ); Temp is decreasing, Speed ( "$SPEED_hex_old" ) is kept."
                    else
                        #   CPU is not getting cooler, speeding up
                        diff=$(( $CPU_T_new - $Target_Temp ))
                        #echo $diff
                        if [ $diff -ge $JumpTemp ]; then
                            SPEED_hex_new=$(( $SPEED_hex_old + $Jump ))
                            SPEED_hex_new=$(printf "0x%X\n" $SPEED_hex_new)
                            echo $(date +%Y%m%d-%H%M%S)" WARNING: Temp is not decreasing, Jumping up the fan to: "$SPEED_hex_new
                            ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI raw 0x30 0x30 0x02 0xff $SPEED_hex_new >/dev/null 2>&1
                        else
                            SPEED_hex_new=$(( $SPEED_hex_old + $Steps ))
                            SPEED_hex_new=$(printf "0x%X\n" $SPEED_hex_new)
                            echo $(date +%Y%m%d-%H%M%S)" WARNING: Temp is not decreasing, speeding up the fan to: "$SPEED_hex_new
                            ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI raw 0x30 0x30 0x02 0xff $SPEED_hex_new >/dev/null 2>&1
                        fi
                            
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
                        diff=$(( $Target_Temp - $CPU_T_new ))
                        #echo $diff
                        if [ $diff -ge $JumpTemp ]; then
                            SPEED_hex_new=$(( $SPEED_hex_old - $Jump ))
                            SPEED_hex_new=$(printf "0x%X\n" $SPEED_hex_new)
                            echo $(date +%Y%m%d-%H%M%S)" WARNING: Temp is getting cooler ( "$CPU_T_new" ), Jump down the fan to: "$SPEED_hex_new
                            ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI raw 0x30 0x30 0x02 0xff $SPEED_hex_new >/dev/null 2>&1
                        else
                            SPEED_hex_new=$(( $SPEED_hex_old - $Steps ))
                            SPEED_hex_new=$(printf "0x%X\n" $SPEED_hex_new)
                            echo $(date +%Y%m%d-%H%M%S)" WARNING: Temp is getting cooler ( "$CPU_T_new" ), speeding down the fan to: "$SPEED_hex_new
                            ipmitool -I lanplus -H $Host_IPMI -U $User_IPMI -P $Passw_IPMI -y $EncKey_IPMI raw 0x30 0x30 0x02 0xff $SPEED_hex_new >/dev/null 2>&1
                        fi
                    fi
                fi
            fi
        #   Updating OLD Values
            CPU_T_old=$CPU_T_new
            SPEED_hex_old=$(printf "0x%X\n" $SPEED_hex_new)
            loop=$(( $loop + 1 ))
        #   Verifying if parameters in .JSON file changued
            if [ $Interval -ne $(cat $1 | jq --raw-output '.Program_config.Interval') ]; then
                Interval=$(cat $1 | jq --raw-output '.Program_config.Interval')
                echo $(date +%Y%m%d-%H%M%S)" WARNING: Interval value changued to: "$Interval
            fi
            if [ $Max_CPU_Temp -ne $(cat $1 | jq --raw-output '.Program_config.Max_CPU_Temp') ]; then
                Max_CPU_Temp=$(cat $1 | jq --raw-output '.Program_config.Max_CPU_Temp')
                echo $(date +%Y%m%d-%H%M%S)" WARNING: Max_CPU_Temp value changued to: "$Max_CPU_Temp
            fi
            if [ $Target_Temp -ne $(cat $1 | jq --raw-output '.Program_config.Target_Temp') ]; then
                Target_Temp=$(cat $1 | jq --raw-output '.Program_config.Target_Temp')
                echo $(date +%Y%m%d-%H%M%S)" WARNING: Target_Temp value changued to: "$Target_Temp
            fi
            if [ $Hist -ne $(cat $1 | jq --raw-output '.Program_config.Hist') ]; then
                Hist=$(cat $1 | jq --raw-output '.Program_config.Hist')
                echo $(date +%Y%m%d-%H%M%S)" WARNING: Hist value changued to: "$Hist
            fi
            if [[ $Steps -ne $(cat $1 | jq --raw-output '.Program_config.Steps') ]]; then
                Steps=$(cat $1 | jq --raw-output '.Program_config.Steps')
                echo $(date +%Y%m%d-%H%M%S)" WARNING: Steps value changued to: "$Steps
            fi
            if [[ $Jump -ne $(cat $1 | jq --raw-output '.Program_config.Jump') ]]; then
                Jump=$(cat $1 | jq --raw-output '.Program_config.Jump')
                echo $(date +%Y%m%d-%H%M%S)" WARNING: Jump value changued to: "$Jump
            fi
            if [ $JumpTemp -ne $(cat $1 | jq --raw-output '.Program_config.JumpTemp') ]; then
                JumpTemp=$(cat $1 | jq --raw-output '.Program_config.JumpTemp')
                echo $(date +%Y%m%d-%H%M%S)" WARNING: JumpTemp value changued to: "$JumpTemp
            fi
        
        echo "-------------------- loop #"$loop"--------------------"
        sleep $Interval
        #exit=1
    done
    echo $(date +%Y%m%d-%H%M%S)" INFO: Exit"
exit 0