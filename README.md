# Fan-Controllers
## Asustor AS6212RD

A script which will monitor disk(s) temp. It take the hottest disk into account

## DELL R320

A VERY basic script to control the fan speed based on CPU Temp and fully customizable via JSON file

### Change Log:
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
                than "JumpTemp" value, then, the fan speed will "Jump" the speed,
                so "Target_Temp" will be reached faster.
