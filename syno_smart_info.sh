#!/usr/bin/env bash
#------------------------------------------------------------------------------
# Show Synology smart test progress or smart health and attributes
#------------------------------------------------------------------------------
# https://www.backblaze.com/blog/hard-drive-smart-stats/
# https://www.backblaze.com/blog/what-smart-stats-indicate-hard-drive-failures/
# https://www.backblaze.com/blog/making-sense-of-ssd-smart-stats/
#------------------------------------------------------------------------------

scriptver="v1.0.0"
script=Synology_SMART_info
#repo="007revad/Synology_SMART_info"

# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver"

# Get NAS model
model=$(cat /proc/sys/kernel/syno_hw_version)

# Get DSM full version
productversion=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION productversion)
buildphase=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildphase)
buildnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildnumber)
smallfixnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION smallfixnumber)

# Show DSM full version and model
if [[ $buildphase == GM ]]; then buildphase=""; fi
if [[ $smallfixnumber -gt "0" ]]; then smallfix="-$smallfixnumber"; fi
echo -e "${model} DSM $productversion-$buildnumber$smallfix $buildphase"

# Get DSM major version
dsm=$(get_key_value /etc.defaults/VERSION majorversion)


# Check if -a or --all option used
if [[ ${1,,} == "--all" ]] || [[ ${1,,} == "-a" ]]; then
    all=yes
fi

# Shell Colors
#Black='\e[0;30m'     # ${Black}
#Red='\e[0;31m'        # ${Red}
LiteRed='\e[1;31m'    # ${LiteRed}
#Green='\e[0;32m'     # ${Green}
#LiteGreen='\e[0;32m' # ${LiteGreen}
Yellow='\e[0;33m'     # ${Yellow}
#Blue='\e[0;34m'      # ${Blue}
#Purple='\e[0;35m'    # ${Purple}
Cyan='\e[0;36m'       # ${Cyan}
#White='\e[0;37m'     # ${White}
Error='\e[41m'        # ${Error}
Off='\e[0m'           # ${Off}

ding(){ 
    printf \\a
}

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    ding
    echo -e "\n${Error}ERROR${Off} This script must be run as sudo or root!\n"
    exit 1  # Not running as root
fi


show_drive_model(){ 
    # Get drive model
    # $drive is sata1 or sda or usb1 etc
    model=$(cat "/sys/block/$drive/device/model")
    model=$(printf "%s" "$model" | xargs)  # trim leading and trailing white space

    # Get drive serial number
    if echo "$drive" | grep nvme >/dev/null ; then
        serial=$(cat "/sys/block/$drive/device/serial")
    else
        serial=$(cat "/sys/block/$drive/device/syno_disk_serial")
    fi
    serial=$(printf "%s" "$serial" | xargs)  # trim leading and trailing white space

    # Show drive model and serial
    echo -e "\n${Cyan}$model${Off} ${Yellow}$serial${Off}"
}

smart_all(){ 
    # Show all SMART attributes
    # $drive is sata1 or sda or usb1 etc
    echo ""
    readarray -t att_array < <(smartctl -A -f brief -d sat -T permissive "/dev/$drive" | tail -n +7)
    for strIn in "${att_array[@]}"; do
        # Remove lines containing ||||||_ to |______
        if ! echo "$strIn" | grep '|_' >/dev/null ; then
            # Remove columns 36 to 78
            strOut="${strIn:0:36}${strIn:78}"
            check="$(echo "$strOut" | xargs | awk '{print $1}')"
            if [[ $check == 5 ]] || [[ $check == 10 ]] || [[ $check == 187 ]] || [[ $check == 188 ]] ||\
                [[ $check == 196 ]] || [[ $check == 197 ]] || [[ $check == 198 ]];
            then
                # Highlight indicators of drive failure
                echo -e "${Yellow}${strOut}${Off}"
            else
                echo "$strOut"
            fi
        fi
    done
}

show_health(){
    # Show drive health
    # $drive is sata1 or sda or usb1 etc
    readarray -t health_array < <(smartctl -H -d sat -T permissive /dev/"$drive" | tail -n +5)
    for strIn in "${health_array[@]}"; do
        if echo "$strIn" | awk '{print $1}' | grep -E '[0-9]' >/dev/null ||\
           echo "$strIn" | awk '{print $1}' | grep 'ID#' >/dev/null ; then

            # Remove columns 36 to 78
            strOut="${strIn:0:36}${strIn:78}"

            # Remove columns 65 to 74
            strOut="${strOut:0:65}${strOut:74}"

            # Remove columns after 77
            strOut="${strOut:0:77}"

            echo "$strOut"
        else
            if [[ -n "$strIn" ]]; then  # Don't echo blank line
                echo "$strIn"
            fi
        fi
    done

    # Show error counter
    smartctl -l error /dev/"$drive" | grep -iE 'error.*logg'

    # Show SMART attributes if health != passed
    health=$(smartctl -H -d sat -T permissive /dev/"$drive" | tail -n +5)
    if ! echo "$health" | grep PASSED >/dev/null || [[ $all == "yes" ]]; then
        smart_all
    fi
}

smart_nvme(){ 
    # $1 is type
    if [[ $1 == "error-log" ]]; then
        # Retrieve Error Log and show error count
        errlog="$(nvme error-log "/dev/$drive" | grep error_count | uniq)"
        errcount="$(echo "$errlog" | awk '{print $3}')"
        if [[ $errcount -gt "0" ]]; then
            echo -e "SMART Errors Logged: ${LiteRed}$errcount${Off}"
        else
            echo "No SMART Errors Logged"
        fi
    elif [[ $1 == "smart-log" ]]; then
        # Retrieve SMART Log
        echo ""
        nvme smart-log "/dev/$drive"
        echo ""
    elif [[ $1 == "smart-log-add" ]]; then
        # Retrieve additional SMART Log
        nvme smart-log-add "/dev/$drive"    # Does not work
    elif [[ $1 == "self-test-log" ]]; then
        # Retrieve the SELF-TEST Log
        nvme self-test-log "/dev/$drive"    # Does not work
    fi
}


# Add drives to drives array
for d in /sys/block/*; do
    # $d is /sys/block/sata1 etc
    case "$(basename -- "${d}")" in
        sd*|hd*)
            if [[ $d =~ [hs]d[a-z][a-z]?$ ]]; then
                drives+=("$(basename -- "${d}")")
            fi
        ;;
        sata*|sas*)
            if [[ $d =~ (sas|sata)[0-9][0-9]?[0-9]?$ ]]; then
                drives+=("$(basename -- "${d}")")
            fi
        ;;
        nvme*)
            if [[ $d =~ nvme[0-9][0-9]?n[0-9][0-9]?$ ]]; then
                nvmes+=("$(basename -- "${d}")")
            fi
        ;;
        nvc*)  # M.2 SATA drives (in PCIe card only?)
            if [[ $d =~ nvc[0-9][0-9]?$ ]]; then
                drives+=("$(basename -- "${d}")")
            fi
        ;;
        usb*)
            if [[ $d =~ usb[0-9]?[0-9]?$ ]]; then
                drives+=("$(basename -- "${d}")")
            fi
        ;;
    esac
done


# HDD and SSD
for drive in "${drives[@]}"; do
    # Show drive model and serial
    show_drive_model

    # Show SATA/SAS drive SMART info
    if [[ $dsm -gt "6" ]]; then
        # DSM 7 or newer

        # Show SMART test status if SMART test running
        percentleft=$(smartctl -a -d sat -T permissive /dev/"$drive" | grep "  Self-test routine in progress" | cut -d " " -f9-13)
        if [[ $percentleft ]]; then
            hourselapsed=$(smartctl -a -d sat -T permissive /dev/"$drive" | grep "  Self-test routine in progress" | cut -d " " -f21)
            echo "Drive $model $serial $percentleft remaining, $hourselapsed hours elapsed."
        else
            # Show drive health
            show_health
        fi
    else
        # DSM 6 or older

        # Show SMART test status if SMART test running
        percentdone=$(smartctl -a -d sat -T permissive /dev/"$drive" | grep "ScanStatus" | cut -d " " -f3-4)
        if [[ $percentdone ]]; then
            hourselapsed=$(smartctl -a -d sat -T permissive /dev/"$drive" | grep "  Self-test routine in progress" | cut -d " " -f21)
            echo "Drive $model $serial ${percentdone}% done."
        else
            # Show drive health
            show_health
        fi
    fi
done

# NVMe
for drive in "${nvmes[@]}"; do
    # Show drive model and serial
    show_drive_model

    smart_nvme error-log
    if [[ $errcount -gt "0" ]] || [[ $all == "yes" ]]; then
        smart_nvme smart-log        
    fi
done

echo -e "\nFinished\n"

exit

