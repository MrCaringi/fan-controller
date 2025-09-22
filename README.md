# Fan-Controllers
## Asustor AS6212RD

A script which will monitor disk(s) temp. It monitor the hottest disk in order to change the fan speed

## DELL R320

A VERY basic script to control the fan speed based on CPU Temp and fully customizable via JSON file
> It should work on any DELL server, but it was tested on R320 model.
thanks to @diferentec for the original script used as base for this one.

### Change Log:
    v1.3.1  2020-10-29
            Odd Values Management
            *   Fixing odd values when the environment temp is very low 
                and when "jumping" down, the calculated speed gets values below 0x00
    v1.3    2020-10-28
            Fine Tuning without stoping the script:
            *   Now the following variables can be modified when the script is running, 
                at the end of every loop it wil be reloaded
            *   When a variable is modified, the log will be populated with the change
            *   The modificable variables are: 
                Interval, Max_CPU_Temp, Target_Temp, Hist, Steps, Jump, JumpTemp
            Improved fan control
            *   A new couple of variables are included:
                when the diference between actual temp and "Target_Temp" is bigger (above or below)
                than "JumpTemp" value, then, the fan speed will "Jump" the speed this number of hex steps,
                so "Target_Temp" will be reached faster.

### .JSON config file explanation
{

    "IPMI_config":{
    
        "Host_IPMI": "1.1.1.1",
        
        "User_IPMI": "IDRAC-USER",
        "Passw_IPMI": "IDRAC-PASSWORD",
        "EncKey_IPMI": "0000000000000000000000000000000000000000"
    },
    "Program_config":{
        "Interval": "20",   # in Seconds, how long it will wait until the next check cycle (loop speed)
        "Max_CPU_Temp": "70",   # in °C, Max temp allowed
        "Target_Temp": "60",    # in °C, desired temp
        "JumpTemp": "5",    # in °C, compared to Actual Temp in order to determine if a "Jump" speed (above or below) is needed
        "Hist": "1",    # in °C, "Histeresis", minimal temp change in order to adjust the fan speed
        "Steps": "1",   # in Decimal, how many hex steps will be the fan speed adjusted
        "Jump": "7",    # in Decimal, when the temp difference is to big, this will be the amount of speed to be changed
        "MIN_hex": "0", # in Decimal, minimal speed based on Hexadecimal value (converted to Hex in the program)
        "MAX_hex": "100",   # in decimal, max speed based on Hexadecimal value (converted to Hex in the program)
        "INITIAL_hex": "20" # in Decimal, when the script is started, this will be the initial speed (converted to Hex in the program).
    }
}

# Contributors
<a href="https://github.com/MrCaringi/fan-controller/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=MrCaringi/fan-controller" />
</a>

[contrib.rocks](https://contrib.rocks).
