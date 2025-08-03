#!/usr/bin/env bash
# shellcheck disable=SC2317
#------------------------------------------------------------------------------
# Show Synology smart test progress or smart health and attributes
#
# GitHub: https://github.com/007revad/Synology_SMART_info
# Script verified at https://www.shellcheck.net/
#
# To run in a shell (replace /volume1/scripts/ with path to script):
# sudo /volume1/scripts/syno_smart_info.sh
#------------------------------------------------------------------------------
# References:
# https://www.backblaze.com/blog/hard-drive-smart-stats/
# https://www.backblaze.com/blog/what-smart-stats-indicate-hard-drive-failures/
# https://www.backblaze.com/blog/making-sense-of-ssd-smart-stats/
#------------------------------------------------------------------------------
# References for converting Seagate raw values:
# https://codeberg.org/SWEETGOOD/shell-scripts#parse-raw-smart-values-seagate-sh
# https://codeberg.org/SWEETGOOD/shell-scripts/raw/branch/main/parse-raw-smart-values-seagate.sh
#
# online Seagate SMART value convertor
# https://www.disktuna.com/seagate-raw-smart-attributes-to-error-convertertest/#102465319
#------------------------------------------------------------------------------

scriptver="v1.3.13"
script=Synology_SMART_info
repo="007revad/Synology_SMART_info"

# Get NAS model
model=$(cat /proc/sys/kernel/syno_hw_version)

# Get NAS hostname
host_name=$(hostname)

# Get DSM full version
productversion=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION productversion)
buildphase=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildphase)
buildnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildnumber)
smallfixnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION smallfixnumber)

# Get DSM major version
dsm=$(get_key_value /etc.defaults/VERSION majorversion)

# Get smartctl location and check if version 7
if which smartctl7 >/dev/null; then
    # smartmontools 7 from SynoCli Disk Tools is installed
    smartctl=$(which smartctl7)
    smartversion=7
else
    smartctl=$(which smartctl)
fi

ding(){ 
    printf \\a
}

usage(){ 
    cat <<EOF
$script $scriptver - by 007revad

Usage: $(basename "$0") [options]

Options:
  -a, --all             Show all SMART attributes
  -e, --email           Disable colored text in output scheduler emails
  -h, --help            Show this help message
  -v, --version         Show the script version

EOF
    exit 1
}

scriptversion(){ 
    cat <<EOF
$script $scriptver - by 007revad

See https://github.com/$repo
EOF
    exit 0
}

# Save options used
args=("$@")

# Check for flags with getopt
if options="$(getopt -o abcdefghijklmnopqrstuvwxyz0123456789 -l \
    all,email,help,version,debug \
    -- "$@")"; then
    eval set -- "$options"
    while true; do
        case "${1,,}" in
            -a|--all)           # Show all SMART attributes
                all=yes
                ;;
            -e|--email)         # Disable colour text in task scheduler emails
                color=no
                ;;
            -h|--help)          # Show usage options
                usage
                ;;
            -v|--version)       # Show script version
                scriptversion
                ;;
            -d|--debug)         # Show and log debug info
                debug=yes
                ;;
            --)
                shift
                break
                ;;
            *)                  # Show usage options
                echo -e "Invalid option '$1'\n"
                usage "$1"
                ;;
        esac
        shift
    done
else
    echo
    usage
fi

# Shell Colors
if [[ $color != "no" ]]; then
    #Black='\e[0;30m'     # ${Black}
    #Red='\e[0;31m'       # ${Red}
    LiteRed='\e[1;31m'    # ${LiteRed}
    #Green='\e[0;32m'     # ${Green}
    LiteGreen='\e[1;32m'  # ${LiteGreen}
    Yellow='\e[0;33m'     # ${Yellow}
    #Blue='\e[0;34m'      # ${Blue}
    #Purple='\e[0;35m'    # ${Purple}
    Cyan='\e[0;36m'       # ${Cyan}
    #White='\e[0;37m'     # ${White}
    Error='\e[41m'        # ${Error}
    Off='\e[0m'           # ${Off}
else
    echo ""  # For task scheduler email readability
fi

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    ding
    echo -e "\n${Error}ERROR${Off} This script must be run as sudo or root!\n"
    exit 1  # Not running as root
fi

# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver - by 007revad"

# Show hostname, model and DSM full version
if [[ $buildphase == GM ]]; then buildphase=""; fi
if [[ $smallfixnumber -gt "0" ]]; then smallfix="-$smallfixnumber"; fi
echo -e "$host_name $model DSM $productversion-$buildnumber$smallfix $buildphase"
echo "Using smartctl $("$smartctl" --version | head -1 | awk '{print $2}')"

# Show options used
if [[ ${#args[@]} -gt "0" ]]; then
    echo "Using options: ${args[*]}"
fi

#------------------------------------------------------------------------------
# Check latest release with GitHub API

# Get latest release info
# Curl timeout options:
# https://unix.stackexchange.com/questions/94604/does-curl-have-a-timeout
#release=$(curl --silent -m 10 --connect-timeout 5 \
#    "https://api.github.com/repos/$repo/releases/latest")

# Use wget to avoid installing curl in Ubuntu
release=$(wget -qO- -q --connect-timeout=5 \
    "https://api.github.com/repos/$repo/releases/latest")

# Release version
tag=$(echo "$release" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
#shorttag="${tag:1}"

if ! printf "%s\n%s\n" "$tag" "$scriptver" |
        sort --check=quiet --version-sort >/dev/null ; then
    echo -e "\n${Cyan}There is a newer version of this script available.${Off}"
    echo -e "Current version: ${scriptver}\nLatest version:  $tag"
fi

#------------------------------------------------------------------------------

get_drive_num(){ 
    drive_num=""
    disk_id=""
    disk_cnr=""
    disk_cnridx=""
    eunit_num=""
    eunit_model=""
    eunit=""
    # Get Drive number
    disk_id=$(synodisk --get_location_form "/dev/$drive" | grep 'Disk id:' | awk '{print $NF}')
    disk_cnr=$(synodisk --get_location_form "/dev/$drive" | grep 'Disk cnr:' | awk '{print $NF}')
    disk_cnridx=$(synodisk --get_location_form "/dev/$drive" | grep 'Disk cnridx:' | awk '{print $NF}')

    # Get eunit model and port number
    if [[ $disk_cnridx -gt "0" ]]; then
        eunit_num="$disk_cnridx"
        eunit_model=$(syno_slot_mapping "/dev/$drive" | grep "Eunit port $disk_cnridx" | awk '{print $NF}')
        eunit="(${eunit_model}-$eunit_num)"
    fi

    if [[ $disk_cnr -eq "4" ]]; then
        drive_num="USB Drive  "
    elif [[ $eunit ]]; then
        drive_num="Drive $disk_id $eunit  "
    else
        drive_num="Drive $disk_id  "
    fi
}

get_nvme_num(){ 
    # Get M.2 Drive number
    drive_num=""
    pcislot=""
    cardslot=""
    if nvme=$(synonvme --get-location "/dev/$drive"); then
        if [[ ! $nvme =~ "PCI Slot: 0" ]]; then
            pcislot="$(echo "$nvme" | cut -d"," -f2 | awk '{print $NF}')-"
        fi
        cardslot="$(echo "$nvme" | awk '{print $NF}')"
    else
        pcislot="$(basename -- "$drive")"
        cardslot=""
    fi
    drive_num="M.2 Drive $pcislot$cardslot  "
}

show_drive_model(){ 
    # Get drive model
    # $drive is sata1 or sda or usb1 etc
    #vendor=$(cat "/sys/block/$drive/device/vendor")
    #vendor=$(printf "%s" "$vendor" | xargs)  # trim leading and trailing white space

    model=$(cat "/sys/block/$drive/device/model")
    model=$(printf "%s" "$model" | xargs)  # trim leading and trailing white space

    # Get drive serial number
    if echo "$drive" | grep nvme >/dev/null ; then
        serial=$(cat "/sys/block/$drive/device/serial")
    else
        serial=$(cat "/sys/block/$drive/device/syno_disk_serial")
    fi
    serial=$(printf "%s" "$serial" | xargs)  # trim leading and trailing white space

    # Get drive serial number with smartctl for USB drives
#    if [[ -z "$serial" && "${drive:0:4}" != "nvme" ]]; then
    if [[ -z "$serial" ]]; then
        serial=$("$smartctl" -i -d sat /dev/"$drive" | grep Serial | cut -d":" -f2 | xargs)
    fi

    # Show drive model and serial
    #echo -e "\n${Cyan}${drive_num}${Off}$model  ${Yellow}$serial${Off}"
    echo -e "\n${Cyan}${drive_num}${Off}$model  $serial  /dev/$drive"
    #echo -e "\n${Cyan}${drive_num}${Off}$vendor $model  $serial"
}

smart_all(){ 
    # Show all SMART attributes
    # $drive is sata1 or sda or usb1 etc
    echo ""
    if [[ $seagate == "yes" ]] && [[ $smartversion == 7 ]]; then
        readarray -t att_array < <("$smartctl" -A -f brief -d sat -T permissive -v 1,raw48:54 -v 7,raw48:54 -v 195,raw48:54 "/dev/$drive" | tail -n +7)
    else
        readarray -t att_array < <("$smartctl" -A -f brief -d sat -T permissive "/dev/$drive" | tail -n +7)
    fi
    for strIn in "${att_array[@]}"; do
        # Remove lines containing ||||||_ to |______
        if ! echo "$strIn" | grep '|_' >/dev/null ; then
            # Remove columns 36 to 78
            strOut="${strIn:0:36}${strIn:78}"
            check="$(echo "$strOut" | xargs | awk '{print $1}')"
            if [[ $check == 5 ]] || [[ $check == 10 ]] || [[ $check == 187 ]] || [[ $check == 188 ]] ||\
                [[ $check == 196 ]] || [[ $check == 197 ]] || [[ $check == 198 ]];
            then
                # Highlight indicators of drive failure in yellow
                echo -e "${Yellow}${strOut}${Off}"
            #if [[ $check == 1 ]] || [[ $check == 5 ]] || [[ $check == 7 ]]\
            #    || [[ $check == 10 ]] || [[ $check == 187 ]] || [[ $check == 188 ]] ||\
            #    [[ $check == 196 ]] || [[ $check == 197 ]] || [[ $check == 198 ]];
            else
                echo "$strIn"
            fi
        fi
    done
}

short_attibutes(){ 
    if [[ "$strIn" ]]; then
        var1=$(echo "$strIn" | awk '{printf "%-28s", $2}')
        var2=$(echo "$strIn" | awk '{printf $10}' | awk -F"+" '{print $1}' | cut -d"h" -f1)
        if [[ ${var2:0:1} -gt "0" && $2 == "zero" ]]; then
            echo -e "$1 ${Yellow}$var1${Off} ${LiteRed}$var2${Off}"
            if [[ $var2 -gt "0" ]]; then
                warn=$((warn +1))
            fi
        elif [[ ${var2:0:1} -gt "0" && $2 == "none" ]]; then
            echo -e "$1 $var1 $var2"
        else
            echo -e "$1 ${Yellow}$var1${Off} $var2"
        fi
    fi
}

show_health(){
    # $drive is sata1 or sda or usb1 etc
    local att194

    # Show drive overall health
    readarray -t health_array < <("$smartctl" -H -d sat -T permissive /dev/"$drive" | tail -n +5)
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
                if $(echo "$strIn" | grep -qi PASSED); then
                    echo -e "SMART overall-health self-assessment test result: ${LiteGreen}PASSED${Off}"
                else
                    echo "$strIn"
                fi
            fi
        fi
    done

    # Show error counter
    #"$smartctl" -l error /dev/"$drive" | grep -iE 'error.*logg'

    # Retrieve Error Log and show error count
    errlog="$("$smartctl" -l error /dev/"$drive" | grep -iE 'error.*logg')"
    errcount="$(echo "$errlog" | awk '{print $3}')"
    #echo "$errlog"
    if [[ $errcount -gt "0" ]]; then
    #if [[ $errcount -eq "0" ]]; then  # debug
        errtotal=$((errtotal +errcount))
        echo -e "SMART Error Counter Log:         ${LiteRed}$errcount${Off}"
    else
        echo -e "SMART Error Counter Log:         ${LiteGreen}No Errors Logged${Off}"
    fi

    # Show SMART attributes
    health=$("$smartctl" -H -d sat -T permissive /dev/"$drive" | tail -n +5)
    if ! echo "$health" | grep PASSED >/dev/null || [[ $all == "yes" ]]; then
        # Show all SMART attributes if health != passed
        smart_all
    else
        # Show only important SMART attributes
        if [[ $seagate == "yes" ]] && [[ $smartversion == 7 ]]; then
            readarray -t smart_atts < <("$smartctl" -A -d sat -v 1,raw48:54 -v 7,raw48:54 -v 195,raw48:54 /dev/"$drive")
        else
            readarray -t smart_atts < <("$smartctl" -A -d sat /dev/"$drive")
        fi
        # Decide if show airflow temperature
        if echo "${smart_atts[*]}" | grep -c '194 Temp' >/dev/null; then
            att194=yes
        fi
        for strIn in "${smart_atts[@]}"; do
            if [[ ${strIn:0:3} == "  1" ]]; then
                # 1 Raw read error rate
                if [[ $seagate == "yes" ]]; then
                    if [[ $smartversion == 7 ]]; then
                        short_attibutes "  1" zero
                    else
                        short_attibutes "  1" none
                    fi
                else
                    short_attibutes "  1"
                fi
            elif [[ ${strIn:0:3} == "  5" ]]; then
                # 5 Reallocated sectors - scrutiny and BackBlaze
                short_attibutes "  5" zero
            elif [[ ${strIn:0:3} == "  7" ]]; then
                # 7 Seek_Error_Rate
                if [[ $seagate == "yes" ]]; then
                    if [[ $smartversion == 7 ]]; then
                        short_attibutes "  7" zero
                    else
                        short_attibutes "  7" none
                    fi
                else
                    short_attibutes "  7"
                fi
            elif [[ ${strIn:0:3} == "  9" ]]; then
                # 9 Power on hours
                short_attibutes "  9" none
            elif [[ ${strIn:0:3} == " 10" ]]; then
                # 10 Spin_Retry_Count - scrutiny
                short_attibutes " 10" none
            elif [[ ${strIn:0:3} == "187" ]]; then
                # 187 Current pending sectors - BackBlaze
                short_attibutes "187" zero
            elif [[ ${strIn:0:3} == "188" ]]; then
                # 188 Current pending sectors - BackBlaze
                short_attibutes "188" zero
            elif [[ ${strIn:0:3} == "190" && -z $att194 ]]; then
                # 190 Airflow_Temperature
                short_attibutes "190" none
            elif [[ ${strIn:0:3} == "194" ]]; then
                # 194 Temperature - scrutiny
                short_attibutes "194" none
            elif [[ ${strIn:0:3} == "195" ]]; then
                # 195 Hardware_ECC_Recovered aka ECC_On_the_Fly_Count
                if [[ $seagate == "yes" ]]; then
                    if [[ $smartversion == 7 ]]; then
                        short_attibutes "195" zero
                    else
                        short_attibutes "195" none
                    fi
                else
                    short_attibutes "195"
                fi
            elif [[ ${strIn:0:3} == "197" ]]; then
                # 197 Current pending sectors - scrutiny and BackBlaze
                short_attibutes "197" zero
            elif [[ ${strIn:0:3} == "198" ]]; then
                # 198 Offline uncorrectable - scrutiny and BackBlaze
                short_attibutes "198" zero
            elif [[ ${strIn:0:3} == "199" ]]; then
                # 199 UDMA_CRC_Error_Count
                short_attibutes "199" zero
            elif [[ ${strIn:0:3} == "200" ]]; then
                # 200 Multi_Zone_Error_Rate - WD
                short_attibutes "200" zero
            fi
        done
    fi
}

smart_nvme(){ 
    # $1 is log type
    if [[ $1 == "error-log" ]]; then
        # Retrieve Error Log and show error count
        errlog="$(nvme error-log "/dev/$drive" | grep error_count | uniq)"
        errcount="$(echo "$errlog" | awk '{print $3}')"
        #echo "$errlog"
        if [[ $errcount -gt "0" ]]; then
        #if [[ $errcount -eq "0" ]]; then  # debug
            errtotal=$((errtotal +errcount))
            echo -e "SMART Error Counter Log:         ${LiteRed}$errcount${Off}"
        else
            echo -e "SMART Error Counter Log:         ${LiteGreen}No Errors Logged${Off}"
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

short_attibutes_nvme(){ 
    if [[ "$strIn" ]]; then
        var1="$3"
        var2=$(echo "$strIn" | cut -d":" -f2 | xargs)
        if [[ ${var2:0:1} -gt "0" && $2 == "zero" ]]; then
            echo -e "${Yellow}$var1${Off} ${LiteRed}$var2${Off}"
        elif [[ ${var2:0:1} -gt "0" && $2 == "none" ]]; then
            echo -e "$var1 $var2"
        else
            echo -e "${Yellow}$var1${Off} $var2"
        fi
    fi
}

show_health_nvme(){ 
    # $drive is nvme0 etc

    # Show only important SMART attributes
    readarray -t smart_atts < <(nvme smart-log /dev/"$drive")
    for strIn in "${smart_atts[@]}"; do
        nvme_att="$(echo "$strIn" | cut -d":" -f1 | xargs)"

        if [[ $nvme_att == "critical_warning" ]]; then
            # 1 Critical_Warning
            short_attibutes_nvme "critical_warning" zero "  1 Critical_Warning            "
        elif [[ $nvme_att == "temperature" ]]; then
            # 2 Temperature - scrutiny
            short_attibutes_nvme "temperature" none "  2 Temperature                 "
        elif [[ $nvme_att == "percentage_used" ]]; then
            # 5 Percentage Used
            short_attibutes_nvme "percentage_used" none "  5 Percentage Used             "
        elif [[ $nvme_att == "power_on_hours" ]]; then
            # 12 Power On Hours
            short_attibutes_nvme "power_on_hours" none " 12 Power On Hours              "
        elif [[ $nvme_att == "unsafe_shutdowns" ]]; then
            # 13 Unsafe Shutdowns
            short_attibutes_nvme "unsafe_shutdowns" zero " 13 Unsafe Shutdowns            "
        elif [[ $nvme_att == "media_errors" ]]; then
            # 14 Media Errors
            short_attibutes_nvme "media_errors" zero " 14 Media Errors                "
        fi
    done
}

not_flash_drive(){ 
    # $1 is /sys/block/sata1 /sys/block/usb1 etc
    # Check if drive is flash drive (not supported by smartctl)
    removable=$(cat "${1}/removable")
    capability=$(cat "${1}/capability")
    if [[ $removable == "1" ]] && [[ $capability == "51" ]]; then
        return 1
    fi
}

is_usb(){ 
    # $1 is /dev/sda or /sys/block/sda etc
    if realpath /sys/block/"$(basename "$1")" | grep -q usb; then
        return 0
    else
        return 1
    fi
}

is_seagate(){
    DEVICE=$("$smartctl" -A -i /dev/"$drive" | awk -F ' ' '/Device Model/{print $3}')
    if [[ "${DEVICE:0:2}" == "ST" ]]; then
        return 0
    else
        return 1
    fi
}

# Add drives to drives array
for d in /sys/block/*; do
    # $d is /sys/block/sata1 etc
    case "$(basename -- "${d}")" in
        sd*|hd*)
            if [[ $d =~ [hs]d[a-z][a-z]?$ ]]; then
                if is_usb "$d"; then  # Add USB drives except flash drives
                    if not_flash_drive "$d"; then
                        drives+=("$(basename -- "${d}")")
                    fi
                else
                    drives+=("$(basename -- "${d}")")  # Add all other drives
                fi
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
                if not_flash_drive "$d"; then
                    drives+=("$(basename -- "${d}")")
                fi
            fi
        ;;
    esac
done

if [[ -z "$errtotal" ]]; then errtotal=0 ; fi

# HDD and SSD
for drive in "${drives[@]}"; do
    # Show drive model and serial
    get_drive_num
    show_drive_model

    # Check if a Seagate drive
    if is_seagate "$drive"; then
        seagate="yes"
    else
        seagate=
    fi

    # Show SATA/SAS drive SMART info
    if [[ $dsm -gt "6" ]]; then
        # DSM 7 or newer

        # Show SMART test status if SMART test running
        percentleft=$("$smartctl" -a -d sat -T permissive /dev/"$drive" | grep "  Self-test routine in progress" | cut -d " " -f9-13)
        if [[ $percentleft ]]; then
            hourselapsed=$("$smartctl" -a -d sat -T permissive /dev/"$drive" | grep "  Self-test routine in progress" | cut -d " " -f21)
            echo "Drive $model $serial $percentleft remaining, $hourselapsed hours elapsed."
        else
            # Show drive health
            show_health
        fi
    else
        # DSM 6 or older

        # Show SMART test status if SMART test running
        percentdone=$("$smartctl" -a -d sat -T permissive /dev/"$drive" | grep "ScanStatus" | cut -d " " -f3-4)
        if [[ $percentdone ]]; then
            hourselapsed=$("$smartctl" -a -d sat -T permissive /dev/"$drive" | grep "  Self-test routine in progress" | cut -d " " -f21)
            echo "Drive $model $serial ${percentdone}% done."
        else
            # Show drive health
            show_health
        fi
    fi
done

# NVMe drives
for drive in "${nvmes[@]}"; do
    # Show drive model and serial
    get_nvme_num
    show_drive_model

    smart_nvme error-log
    if [[ $errcount -gt "0" ]]; then
        errtotal=$((errtotal +errcount))
    fi

    # Show important smart values
    show_health_nvme

    # Show important smart values
    if [[ $errcount -gt "0" ]] || [[ $all == "yes" ]]; then
        smart_nvme smart-log        
    fi
done

echo -e "\nFinished\n"

if [[ $warn -gt "0" ]]; then
    errtotal=$((errtotal +warn))
fi

exit "$errtotal"

