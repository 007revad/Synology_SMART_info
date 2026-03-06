#!/usr/bin/env bash
# shellcheck disable=SC2317,SC2091,SC2076,SC2207
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
#
# https://github.com/Seagate/openSeaChest/wiki/Drive-Health-and-SMART
#
# S.M.A.R.T. attribute list (ATA ans SCSI)
# https://www.hdsentinel.com/smart/smartattr.php
#
# https://linux.die.net/man/8/smartctl
#------------------------------------------------------------------------------

# Attribute ID: 191
# Attribute Name: G-sense error rate
# Description: This value tracks errors resulting from external shock or vibration.
# Other names: G-Sense Error Rate, Shock Sense 

scriptver="v1.4.38"
script=Synology_SMART_info
repo="007revad/Synology_SMART_info"

# Get NAS model
nas_model=$(cat /proc/sys/kernel/syno_hw_version)

# Get NAS hostname
host_name=$(hostname)

# Get DSM full version
productversion=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION productversion)
buildphase=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildphase)
buildnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildnumber)
smallfixnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION smallfixnumber)

# Get DSM major version
dsm=$(get_key_value /etc.defaults/VERSION majorversion)

# Get location of script
scriptpath="$(realpath "$0")"
logpath="${scriptpath%/*}"

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

debug() {
    [[ $debug == "yes" ]] && echo "DEBUG: $*"
}

usage(){ 
    cat <<EOF
$script $scriptver - by 007revad

Usage: $(basename "$0") [options]

Options:
  -a, --all             Show all SMART attributes
  -e, --email           Disable colored text in output scheduler emails
  -i, --increased       Only show important attributes that have increased
  -u, --update          Update the script to the latest version
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
    all,email,increased,update,help,version,debug \
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
            -i|--increased)     # Only display increased attributes
                increased=yes
                ;;
            -u|--update)        # Update the script to the latest version
                update=yes
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

    # For Synomartinfo package's white background
    if [[ $scriptpath =~ "/@appstore/Synosmartinfo/bin/syno_smart_info.sh" ]]; then
        #Yellow='\e[0;93m'      # ${Yellow}
        #Yellow='\e[1;33m'      # ${Yellow}
        Yellow='\e[0;34m'      # ${Yellow}  # Purple
        YellowPy='\033[0;34m'  # ${Yellow}  # Purple
        #Cyan='\e[0;96m'        # ${Cyan}
        Cyan='\e[1;36m'        # ${Cyan}
    fi
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
echo -e "$host_name $nas_model DSM $productversion-$buildnumber$smallfix $buildphase"
echo "Using smartctl $("$smartctl" --version | head -1 | awk '{print $2}')"

# Show options used
if [[ ${#args[@]} -gt "0" ]]; then
    echo "Using options: ${args[*]}"
fi

# Reset shell's SECONDS var to later show how long the script took
SECONDS=0

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

    if [[ $update == "yes" ]]; then
        if [[ -f "${logpath}/updateLocalScript.sh" ]]; then
            if bash "${logpath}/updateLocalScript.sh" "${logpath}"; then
                echo -e "syno_smart_info.sh updated"
                exit
            else
                echo -e "Failed to update syno_smart_info.sh!"
                exit 1
            fi
        else
            echo -e "Missing file: ${logpath}/updateLocalScript.sh"
            exit 1
        fi
    elif [[ -f "${logpath}/updateLocalScript.sh" ]]; then
        # Skip if running from Synomartinfo package folder
        if [[ ! $scriptpath =~ "/@appstore/Synosmartinfo/bin/syno_smart_info.sh" ]]; then
            echo -e "Run ${Cyan}syno_smart_info.sh -u${Off} to update."
        fi
    fi
fi


#------------------------------------------------------------------------------

detect_dtype(){ 
    # Default to SAT
    local dtype="sat"

    # If SAS appears at least once, treat as SCSI
    if [ "$("$smartctl" -i /dev/"$drive" 2>/dev/null | grep -c SAS)" -gt 0 ]; then
        dtype="scsi"
    # Else if SATA appears at least once, treat as SAT
    elif [ "$("$smartctl" -i /dev/"$drive" 2>/dev/null | grep -c SATA)" -gt 0 ]; then
        dtype="sat"
    fi

    echo "$dtype"
}

get_drive_num(){ 
    drive_num=""
    disk_id=""
    disk_cnr=""
    #disk_cnridx=""
    #eunit_num=""
    #eunit_model=""
    eunit=""
    # Get Drive number
    disk_id=$(synodisk --get_location_form "/dev/$drive" | grep 'Disk id:' | awk '{print $NF}')
    disk_cnr=$(synodisk --get_location_form "/dev/$drive" | grep 'Disk cnr:' | awk '{print $NF}')
    #disk_cnridx=$(synodisk --get_location_form "/dev/$drive" | grep 'Disk cnridx:' | awk '{print $NF}')

    # Get eunit model and port number
    # Only device tree models have syno_slot_mapping so we use different method
    # /tmp/eunitinfo_2 example contents:
    #  EUnitModel=DX213-2
    #  EUnitDisks=/dev/sdja,/dev/sdjb
    for f in /tmp/eunitinfo_*; do
        if [[ -f "$f" ]]; then
            if grep -q "/dev/$drive" "$f"; then
                eunit="$(get_key_value "$f" EUnitModel)"
            fi
        fi
    done

    if [[ $disk_cnr -eq "4" ]]; then
        drive_num="USB Drive  "
    elif [[ $eunit ]]; then
        drive_num="Drive $disk_id ($eunit)  "
    elif synodisk --enum -t sys | grep -q "/dev/$drive"; then
        # HD6500
        drive_num="System Drive $disk_id  "
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

log_drive(){
    # $1 is "$serial"
    # $2 is "$drive_num"
    # $3 is "$model"
    # $4 is "/dev/$drive"    

    # set_section_key_value has bugs
    # It cannot create a new section
    # It cannot write keys if no key/value pair exist below section
    # So we echo the section with a key/value pair

    first_run=""
    if ! grep '\['"$1"'\]' "$smart_log" >/dev/null; then
        echo -e "[${serial}]\ndrive_num=" >> "$smart_log"
        first_run="yes"
    fi
    set_section_key_value "$smart_log" "$1" drive_num "$2"
    set_section_key_value "$smart_log" "$1" model "$3"
    set_section_key_value "$smart_log" "$1" device "$4"
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
        serial=$("$smartctl" -i -d "$drive_type" /dev/"$drive" | grep Serial | cut -d":" -f2 | xargs)
    fi

    # Show drive model and serial
    if [[ $increased != "yes" ]]; then
        #echo -e "\n${Cyan}${drive_num}${Off}$model  ${Yellow}$serial${Off}"
        echo -e "\n${Cyan}${drive_num}${Off}$model  $serial  /dev/$drive"
        #echo -e "\n${Cyan}${drive_num}${Off}$vendor $model  $serial"
    else
        show_drive_info="\n${Cyan}${drive_num}${Off}$model  $serial  /dev/$drive"
    fi

    # Log drive num, vendor and model to smart.log
    log_drive "$serial" "$drive_num" "$model" "/dev/$drive"
}

# Python-based SMART attribute formatting function using EOF method
print_colored_smart_attribute(){ 
    local line="$1"
    [[ -z "$line" ]] && return
    
    # Pass color disable option to Python
    local color_opt="1"
    if [[ $color == "no" ]]; then
        color_opt="0"
    fi
    
    # Execute Python script using HERE document
    echo "$line" | python3 -c "
import sys
import re

def format_smart_line():
    line = sys.stdin.read().strip()
    color_enabled = bool(int('$color_opt'))
    
    if not line:
        return
    
    script_path = '$scriptpath'
    if re.search(r'/@appstore/Synosmartinfo/bin/syno_smart_info\.sh', script_path):
        # For Synomartinfo package's white background
        YELLOW = '$YellowPy'
    else:
        YELLOW = '\033[0;33m'
    
    OFF = '\033[0m'
    COLOR_IDS = {5, 10, 187, 188, 196, 197, 198}
    
    fields = line.split()
    if len(fields) < 6:
        print(line)
        return
    
    try:
        id_field = fields[0]
        id_num = int(id_field)
    except ValueError:
        print(line)
        return
    
    flags_pattern = re.compile(r'^[POSRCK-]{6}$')
    flags_idx = -1
    
    for i, field in enumerate(fields[1:], 1):
        if flags_pattern.match(field):
            flags_idx = i
            break
    
    if flags_idx == -1 or len(fields) < flags_idx + 5:
        print(line)
        return
    
    attr_name = ' '.join(fields[1:flags_idx])
    flags = fields[flags_idx]
    value = fields[flags_idx + 1]
    worst = fields[flags_idx + 2] 
    thresh = fields[flags_idx + 3]
    fail = fields[flags_idx + 4]
    raw_value = ' '.join(fields[flags_idx + 5:]) if len(fields) > flags_idx + 5 else ''
    
    formatted_line = f'{id_field:<4} {attr_name:<32} {flags:<8} {value:>6} {worst:>6} {thresh:>7} {fail:>6} {raw_value}'
    
    if color_enabled and id_num in COLOR_IDS:
        print(f'{YELLOW}{formatted_line}{OFF}')
    else:
        print(formatted_line)

format_smart_line()
"
}

# SMART header output function
print_smart_header(){ 
    printf "%-4s %-32s %-8s %6s %6s %7s %6s %s\n" \
        "ID#" "ATTRIBUTE_NAME" "FLAGS" "VALUE" "WORST" "THRESH" "FAIL" "RAW_VALUE"
}

# SCSI SMART attribute formatting function (uses SCSI-only parsing)
format_scsi_smart(){ 
    local drive="$1"
    local output

    debug "format_scsi_smart called for drive: $drive"

    # Retrieve SCSI SMART output via wrapper; strip the leading header block
    output=$("$smartctl" -a "/dev/$drive" | tail -n +19)

    debug "SCSI output (first 20 lines):"
    debug "$(echo "$output" | head -20)"

    # Arrays to hold parsed items
    declare -a scsi_ids=()
    declare -a scsi_names=()
    declare -a scsi_values=()

    # Parse 5 patterns and map to standard IDs
    while IFS= read -r line; do
        debug "Processing line: '$line'"

        if [[ "$line" == *"Current Drive Temperature:"* ]]; then
            # Extract temperature number only
            temp_value=$(echo "$line" | grep -o '[0-9]\+' | head -1)
            debug "Found temperature: $temp_value"
            scsi_ids+=(194); scsi_names+=("Current Drive Temperature"); scsi_values+=("$temp_value")

        elif [[ "$line" == *"Accumulated power on time, hours:minutes"* ]]; then
            time_value=$(echo "$line" | awk -F'Accumulated power on time, hours:minutes ' '{print $2}' | xargs)
            debug "Found power on time: '$time_value'"
            scsi_ids+=(9); scsi_names+=("Accumulated power on time"); scsi_values+=("$time_value")

        elif [[ "$line" == *"Accumulated start-stop cycles:"* ]]; then
            cycle_value=$(echo "$line" | awk '{print $NF}')
            debug "Found start-stop cycles: $cycle_value"
            scsi_ids+=(4); scsi_names+=("Accumulated start-stop cycles"); scsi_values+=("$cycle_value")

        elif [[ "$line" == *"Accumulated load-unload cycles:"* ]]; then
            load_value=$(echo "$line" | awk '{print $NF}')
            debug "Found load-unload cycles: $load_value"
            scsi_ids+=(193); scsi_names+=("Accumulated load-unload cycles"); scsi_values+=("$load_value")

        elif [[ "$line" == *"Elements in grown defect list:"* ]]; then
            defect_value=$(echo "$line" | awk '{print $NF}')
            debug "Found defect list elements: $defect_value"
            scsi_ids+=(5); scsi_names+=("Elements in grown defect list"); scsi_values+=("$defect_value")
        fi
    done <<< "$output"

    debug "Found ${#scsi_ids[@]} attributes"
    for ((i=0; i<${#scsi_ids[@]}; i++)); do
        debug "ID=${scsi_ids[i]}, Name='${scsi_names[i]}', Value='${scsi_values[i]}'"
    done

    if [[ ${#scsi_ids[@]} -eq 0 ]]; then
        debug "No SCSI attributes found, showing raw output"
        echo "No SCSI attributes found in expected format"
        echo "$output"
        return
    fi

    # Sort by ID (bubble sort for simplicity)
    local n=${#scsi_ids[@]}
    for ((i=0; i<n-1; i++)); do
        for ((j=0; j<n-i-1; j++)); do
            if [[ ${scsi_ids[j]} -gt ${scsi_ids[j+1]} ]]; then
                # swap id
                tmp=${scsi_ids[j]}; scsi_ids[j]=${scsi_ids[j+1]}; scsi_ids[j+1]=$tmp
                # swap name
                tmp=${scsi_names[j]}; scsi_names[j]=${scsi_names[j+1]}; scsi_names[j+1]=$tmp
                # swap value
                tmp=${scsi_values[j]}; scsi_values[j]=${scsi_values[j+1]}; scsi_values[j+1]=$tmp
            fi
        done
    done

    # Output (SCSI-only summary header and rows)
    printf "%-4s %-40s %s\n" "ID#" "ATTRIBUTE_NAME" "RAW_VALUE"
    for ((i=0; i<${#scsi_ids[@]}; i++)); do
        local id=${scsi_ids[i]} name=${scsi_names[i]} val=${scsi_values[i]}
        if [[ $color != "no" && ( $id -eq 5 ) ]]; then
            printf "${Yellow}%-4s %-40s %s${Off}\n" "$id" "$name" "$val"
        else
            printf "%-4s %-40s %s\n" "$id" "$name" "$val"
        fi
    done
}

smart_all(){
    echo ""

    # Decide device type (sat/scsi) via detect_dtype()
    local drive_type
    drive_type=$(detect_dtype)

    if [[ "$drive_type" == "scsi" ]]; then
        # SCSI path: do not print SAT header or use SAT python formatter.
        # Let the dedicated SCSI formatter read and parse directly.
        format_scsi_smart "$drive"
        return
    fi

    # SAT / non-SCSI path
    print_smart_header

    if [[ $seagate == "yes" ]] && [[ $smartversion -gt "6" ]]; then
        # Get all attributes, skip built-in header (first 6 lines), then drop “ID#” header
        readarray -t att_array < <(
            "$smartctl" -A -f brief -d "$drive_type" -T permissive \
                -v 1,raw48:54 -v 7,raw48:54 -v 188,raw48:54 -v 195,raw48:54 \
                -v 240,msec24hour32 "/dev/$drive" \
            | tail -n +7 \
            | grep -v '^ID#'
        )
    elif [[ $seagate == "yes" ]] && [[ $smartversion -lt "7" ]]; then
        # Get all attributes, skip built-in header (first 6 lines), then drop “ID#” header
        readarray -t att_array < <(
            "$smartctl" -A -f brief -d "$drive_type" -T permissive \
                -v 1,raw48:54,Raw_Read_Error_Rate -v 7,raw48:54,Seek_Error_Rate \
                -v 188,raw48:54,Command_Timeout_Count \
                -v 195,raw48:54,Hardware_ECC_Recovered \
                -v 240,msec24hour32,Head_Flying_Hours "/dev/$drive" \
            | tail -n +7 \
            | grep -v '^ID#'
        )
    else
        # Same for non-Seagate drives
        readarray -t att_array < <(
            "$smartctl" -A -f brief -d "$drive_type" -T permissive "/dev/$drive" \
            | tail -n +7 \
            | grep -v '^ID#'
        )
    fi

    for strIn in "${att_array[@]}"; do
        # Remove lines containing ||||||_ to |______
        if ! echo "$strIn" | grep '|_' >/dev/null ; then
            # Use Python-based formatting instead of original string cutting
            print_colored_smart_attribute "$strIn"
        fi
    done
}

log_bad(){ 
    # $1 is "197 Current_Pending_Sector  0x0032   200   200   000    Old_age   Always       -       52"
    # $1 for SAS is "Elements in grown defect list: 0"
    local var1
    local var2
    if [[ $drive_type == "scsi" ]]; then  # SAS drive
        # Get attribute name
        #var1=$(echo "$strIn" | awk -F':' '{printf $1}')
        var1=$(echo "$1" | awk -F':' '{printf $1}')
        # Get attribute value
        #var2=$(echo "$strIn" | awk -F':' '{printf $2}' | xargs)
        var2=$(echo "$1" | awk -F':' '{printf $2}' | xargs)
    else
        # Get attribute name
        #var1=$(echo "$1" | awk '{printf "%-28s", $2}')
        var1=$(echo "$1" | awk '{printf $2}')
        # Get attribute value
        var2=$(echo "$1" | awk '{printf $10}' | awk -F"+" '{print $1}' | cut -d"h" -f1)
    fi

    var1_trimmed="$(echo "$var1" | xargs)"
    show_increased=""
    previous_att="$(get_section_key_value "$smart_log" "$serial" "$var1_trimmed")"
    if [[ -z $previous_att ]]; then
        # Create ini section if missing
        if ! grep "$serial" "$smart_log" > /dev/null; then
            echo -e "[${serial}]\ndrive_num=" >> "$smart_log"
        fi
        set_section_key_value "$smart_log" "$serial" "$var1_trimmed" "$var2"
    elif [[ $var2 -gt "$previous_att" ]]; then
        set_section_key_value "$smart_log" "$serial" "$var1_trimmed" "$var2"
        show_increased=$'\\t'"Increased by $((var2 - previous_att))"
    elif [[ $var2 -lt "$previous_att" ]]; then
        set_section_key_value "$smart_log" "$serial" "$var1_trimmed" "$var2"
        show_increased=$'\\t'"Decreased by $((previous_att - var2))"
    fi

    # Don't show "Increased by #" or " Decreased by #" if first time adding the drive to smart.log
    if [[ $first_run == "yes" ]]; then
        show_increased=""
    fi
}

log_bad_nvme(){ 
    # $var2 is smart attribute value
    # $var3 is smart attribute name

    var3_trimmed="$(echo "$var3" | xargs)"
    show_increased=""
    previous_att="$(get_section_key_value "$smart_log" "$serial" "$var3_trimmed")"
    if [[ -z $previous_att ]]; then
        # Create ini section if missing
        if ! grep "$serial" "$smart_log" > /dev/null; then
            echo -e "[${serial}]\ndrive_num=" >> "$smart_log"
        fi
        set_section_key_value "$smart_log" "$serial" "$var3_trimmed" "$var2"
    elif [[ $var2 -gt "$previous_att" ]]; then
        set_section_key_value "$smart_log" "$serial" "$var3_trimmed" "$var2"
        show_increased=$'\\t'"Increased by $((var2 - previous_att))"
    elif [[ $var2 -lt "$previous_att" ]]; then
        set_section_key_value "$smart_log" "$serial" "$var3_trimmed" "$var2"
        show_increased=$'\\t'"Decreased by $((previous_att - var2))"
    fi

    # Don't show "Increased by #" or " Decreased by #" if first time adding the drive to smart.log
    if [[ $first_run == "yes" ]]; then
        show_increased=""
    fi
}

short_attibutes(){ 
    # $1 is space padded attribute number like "  5" or "199"
    # $2 is "zero" or "none"
    # $3 is SAS attribute name with padding like "Elements in grown defect list: "
    # $strIn is like "199 UDMA_CRC_Error_Count    0x003e   200   200   000    Old_age   Always       -       0"
    local num
    if [[ $1 == "_" ]]; then
        num=""
    else
        num="$1 "
    fi

    if [[ "$strIn" ]]; then
        if [[ $drive_type == "scsi" ]]; then  # SAS drive
            var1="$3"
            # Get attribute value
            var2=$(echo "$strIn" | awk -F':' '{printf $2}' | xargs)
        else
            # Get attribute name with padding like "UDMA_CRC_Error_Count        "
            var1=$(echo "$strIn" | awk '{printf "%-28s", $2}')
            # Get attribute value
            var2=$(echo "$strIn" | awk '{printf $10}' | awk -F"+" '{print $1}' | cut -d"h" -f1)
        fi

        # Remove % from Percentage_Used
        #var2="${var2//%/}"  # Currently not used

        if [[ $2 == "zero" && "${var2:0:1}" -gt "0" ]]; then
            # Log important attributes with raw value greater than 0
            if [[ $var2 -gt "0" ]]; then
                warn=$((warn +1))
                # Log important attributes that should be zero but have raw value greater than 0
                log_bad "$strIn"
            fi
            if [[ $increased != "yes" ]]; then
                echo -e "$num${Yellow}$var1${Off} ${LiteRed}$var2${Off}$show_increased"
            elif [[ $first_run == "yes" ]]; then
                new_atts+=("$num${Yellow}$var1${Off} ${LiteRed}$var2${Off}")
            else
                changed_atts+=("$num${Yellow}$var1${Off} ${LiteRed}$var2${Off}$show_increased")
            fi
        elif [[ $2 == "none" && "${var2:0:1}" -gt "0" ]]; then
            if [[ $increased != "yes" ]]; then
                echo -e "$num$var1 $var2"
            fi
        else
            if [[ $increased != "yes" ]]; then
                echo -e "$num${Yellow}$var1${Off} $var2"
            fi
        fi

        # Log important attributes with 0 raw value
        if [[ $2 == "zero" && $var2 -eq "0" ]]; then
            log_bad "$strIn"
        fi
    fi
}

show_health(){ 
    # $drive is sata1 or sda or usb1 etc
    local att194

    # Decide device type (sat/scsi) via detect_dtype()
    local drive_type
    drive_type=$(detect_dtype)

    # Show drive overall health
    readarray -t health_array < <("$smartctl" -H -d "$drive_type" -T permissive /dev/"$drive" | tail -n +5)
    for strIn in "${health_array[@]}"; do
        if echo "$strIn" | awk '{print $1}' | grep -E '[0-9]' >/dev/null ||\
           echo "$strIn" | awk '{print $1}' | grep 'ID#' >/dev/null ; then

            # Remove columns 36 to 78
            strOut="${strIn:0:36}${strIn:78}"

            # Remove columns 65 to 74
            strOut="${strOut:0:65}${strOut:74}"

            # Remove columns after 77
            strOut="${strOut:0:77}"

            if [[ $increased != "yes" ]]; then
                echo "$strOut"
            fi
        else
            if [[ -n "$strIn" ]]; then  # Don't echo blank line
                if $(echo "$strIn" | grep -qi PASSED); then
                    if [[ $increased != "yes" ]]; then
                        echo -e "SMART overall-health self-assessment test result: ${LiteGreen}PASSED${Off}"
                    fi
                elif $(echo "$strIn" | grep -qi 'Health Status: OK'); then
                    if [[ $increased != "yes" ]]; then
                        echo -e "SMART Health Status:                ${LiteGreen}OK${Off}"
                    fi
                else
                    if [[ $increased != "yes" ]]; then
                        echo "$strIn"
                    fi
                fi
            fi
        fi
    done

    # Show error counter
    #"$smartctl" -l error /dev/"$drive" | grep -iE 'error.*logg'

    # Retrieve Error Log and show error count
    if [[ $drive_type != "scsi" ]]; then  # Not SAS drive
        errlog="$("$smartctl" -l error -d "$drive_type" /dev/"$drive" | grep -iE 'error.*logg')"
        errcount="$(echo "$errlog" | awk '{print $3}')"
        if [[ -z $errlog ]]; then
            errlog="$("$smartctl" -l error -d "$drive_type" /dev/"$drive" | grep -iE 'error count')"
            errcount="$(echo "$errlog" | awk '{print $4}')"
        fi
        if [[ -z $errcount ]]; then
            if [[ $increased != "yes" ]]; then
                "$smartctl" -l error -d "$drive_type" /dev/"$drive" | grep -iE 'not supported'
            fi
        elif [[ $errcount -gt "0" ]]; then
            errtotal=$((errtotal +errcount))
            if [[ $increased != "yes" ]]; then
                echo -e "SMART Error Counter Log:         ${LiteRed}$errcount${Off}"
            fi
        else
            if [[ $increased != "yes" ]]; then
                echo -e "SMART Error Counter Log:         ${LiteGreen}No Errors Logged${Off}"
            fi
        fi
    else
        # SAS drive
        readarray -t sas_errlog_array < <("$smartctl" -d "$drive_type" --all /dev/"$drive")
        for e in "${sas_errlog_array[@]}"; do
            nameA=""
            nameB=""
            valA=""
            valB=""
            if echo "$e" | grep -E '^read:' >/dev/null; then
                nameA="${Yellow}Total uncorrected read errors:      ${Off}"
                valA=$(echo "$e" | awk '{printf $8}')
                nameB="Total corrected read errors:        "
                valB=$(echo "$e" | awk '{printf $5}')
            elif echo "$e" | grep -E '^write:' >/dev/null; then
                nameA="${Yellow}Total uncorrected write errors:     ${Off}"
                valA=$(echo "$e" | awk '{printf $8}')
                nameB="Total corrected write errors:       "
                valB=$(echo "$e" | awk '{printf $5}')
            elif echo "$e" | grep -E '^verify:' >/dev/null; then
                nameA="${Yellow}Total uncorrected verify errors:    ${Off}"
                valA=$(echo "$e" | awk '{printf $8}')
                nameB="Total corrected verify errors:      "
                valB=$(echo "$e" | awk '{printf $5}')
            fi

            # Total uncorrected read/write/verify errors
            if [[ -n $nameA ]] && [[ -n $valA ]]; then  # Don't echo blank line
                if [[ $valA -gt "0" ]]; then
                    if [[ $increased != "yes" ]]; then
                        echo -e "${nameA}${LiteRed}$valA${Off}"
                    fi
                else
                    if [[ $increased != "yes" ]]; then
                        echo -e "${nameA}${valA}"
                    fi
                fi
            fi

            # Total corrected read/write/verify errors
            if [[ -n $nameB ]] && [[ -n $valB ]]; then  # Don't echo blank line
                if [[ $valB -gt "0" ]]; then
                    if [[ $increased != "yes" ]]; then
                        echo -e "${nameB}${LiteRed}$valB${Off}"
                    fi
                else
                    if [[ $increased != "yes" ]]; then
                        echo -e "${nameB}${valB}"
                    fi
                fi
            fi
        done
    fi

    # Show SMART attributes
    health_bad=""
    if [[ $drive_type == "scsi" ]]; then  # SAS drive
        health=$("$smartctl" -H -d "$drive_type" -T permissive /dev/"$drive" | tail -n +5)
        if ! echo "$health" | grep -E 'SMART Health Status.*OK' >/dev/null; then
            if [[ $increased != "yes" ]]; then
                # Show all SMART attributes
                health_bad="yes"
            fi
        fi
    else  # SATA drive
        health=$("$smartctl" -H -d "$drive_type" -T permissive /dev/"$drive" | tail -n +5)
        if ! echo "$health" | grep PASSED >/dev/null; then
            if [[ $increased != "yes" ]]; then
                # Show all SMART attributes
                health_bad="yes"
            fi
        fi
    fi

    if [[ $health_bad == "yes" ]] || [[ $all == "yes" ]]; then
        # Show all SMART attributes if health-bad == yes, or -a/--all option used
        smart_all
    else
        # Show only important SMART attributes
        if [[ $seagate == "yes" ]] && [[ $smartversion -gt "6" ]]; then
            readarray -t smart_atts < <("$smartctl" -A -d "$drive_type" \
            -v 1,raw48:54 -v 7,raw48:54 -v 188,raw48:54 -v 195,raw48:54 /dev/"$drive")
        elif [[ $seagate == "yes" ]] && [[ $smartversion -lt "7" ]]; then
            readarray -t smart_atts < <("$smartctl" -A -d "$drive_type" \
            -v 1,raw48:54,Raw_Read_Error_Rate -v 7,raw48:54,Seek_Error_Rate \
            -v 188,raw48:54,Command_Timeout_Count \
            -v 195,raw48:54,Hardware_ECC_Recovered /dev/"$drive")
        else
            readarray -t smart_atts < <("$smartctl" -A -d "$drive_type" /dev/"$drive")
        fi
        # Decide if show airflow temperature
        if echo "${smart_atts[*]}" | grep -c -E '194.*Temp' >/dev/null; then
            att194=yes
        elif echo "${smart_atts[*]}" | grep -c 'Current Drive Temp' >/dev/null; then
            att194=yes
        fi

        sas_attibutes=()
        for strIn in "${smart_atts[@]}"; do
            if [[ $drive_type == "scsi" ]]; then  # SAS drive
                if [[ $strIn =~ "Elements in grown defect list" ]]; then
                    # 5 Elements in grown defect list
                    #short_attibutes "  5" zero "Elements in grown defect list: "
                    sas_attibutes+=("  5,zero,Elements in grown defect list: ,$strIn")

                elif [[ $strIn =~ "Current Drive Temperature" ]]; then
                    # 194 Current Drive Temperature
                    #short_attibutes "194" none "Current Drive Temperature:     "
                    sas_attibutes+=("194,none,Current Drive Temperature:     ,$strIn")
                fi

            else  # SATA drive
                if [[ ${strIn:0:3} == "  1" ]]; then
                    # 1 Raw read error rate
                    #if [[ $seagate == "yes" ]]; then
                    #    if [[ $smartversion -gt "6" ]]; then
                    #        short_attibutes "  1" zero
                    #    else
                    #        short_attibutes "  1" none
                    #    fi
                    #else
                        short_attibutes "  1" zero
                    #fi
                elif [[ ${strIn:0:3} == "  5" ]]; then
                    # 5 Reallocated sectors - scrutiny and BackBlaze
                    short_attibutes "  5" zero
                elif [[ ${strIn:0:3} == "  7" ]]; then
                    # 7 Seek_Error_Rate
                    #if [[ $seagate == "yes" ]]; then
                    #    if [[ $smartversion -gt "6" ]]; then
                    #        short_attibutes "  7" zero
                    #    else
                    #        short_attibutes "  7" none
                    #    fi
                    #else
                        short_attibutes "  7" zero
                    #fi
                elif [[ ${strIn:0:3} == "  9" ]]; then
                    # 9 Power on hours
                    short_attibutes "  9" none
                elif [[ ${strIn:0:3} == " 10" ]]; then
                    # 10 Spin_Retry_Count - scrutiny
                    short_attibutes " 10" zero
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
                    #if [[ $seagate == "yes" ]]; then
                    #    if [[ $smartversion -gt "6" ]]; then
                    #        short_attibutes "195" zero
                    #    else
                    #        short_attibutes "195" none
                    #    fi
                    #else
                        short_attibutes "195" zero
                    #fi
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
                elif [[ ${strIn:0:3} == "252" ]]; then
                    # 252 Added_Bad_Flash_Blk_Ct - Samsung SSD
                    short_attibutes "252" zero
                fi
            fi
        done

        # Sort SAS smart attributes by ID number
        sas_attibutes_sorted=()
        IFS=$'\n'
        sas_attibutes_sorted=($(sort -g <<<"${sas_attibutes[*]}"))  # Sort array
        unset IFS

        # Show SAS smart attributes sorted by ID number
        for att in "${sas_attibutes_sorted[@]}"; do
            arg1="$(echo "$att" | cut -d',' -f1)"
            arg2="$(echo "$att" | cut -d',' -f2)"
            arg3="$(echo "$att" | cut -d',' -f3)"
            strIn="$(echo "$att" | cut -d',' -f4)"
            short_attibutes "$arg1" "$arg2" "$arg3"
        done
    fi
}

smart_nvme(){ 
    # $1 is log type: error-log, smart-log, smart-log-add or self-test-log
    # $drive is nvme0 etc

    if [[ $1 == "error-log" ]]; then
        # Retrieve Error Log and show error count
        errlog="$(nvme error-log "/dev/$drive" | grep error_count | head -1)"
        errcount="$(echo "$errlog" | awk '{print $3}')"
        if [[ $errcount -gt "0" ]]; then
            errtotal=$((errtotal +errcount))
            if [[ $increased != "yes" ]]; then
                echo -e "SMART Error Counter Log:         ${LiteRed}$errcount${Off}"
            fi
        else
            if [[ $increased != "yes" ]]; then
                echo -e "SMART Error Counter Log:         ${LiteGreen}No Errors Logged${Off}"
            fi
        fi
    elif [[ $1 == "smart-log" ]]; then
        # Retrieve SMART Log
        echo ""
        if [[ $smartversion -gt "6" ]]; then
            # smartctl7 is installed
            #readarray -t nvme_health_array < <(smartctl7 -A /dev/"$drive" | awk '/=== START OF SMART DATA SECTION ===/{flag=1;next}flag')
            readarray -t nvme_health_array < <(smartctl7 -A /dev/"$drive" | awk '/Health Information/{flag=1;next}flag')
        else
            # smartctl is not v7 so we need to use nvme command
            readarray -t nvme_health_array < <(nvme smart-log "/dev/$drive" | awk '/Smart Log for NVME/{flag=1;next}flag')
        fi
        for strIn in "${nvme_health_array[@]}"; do
            if [[ $smartversion -gt "6" ]]; then
                # smartctl7 is installed
                if echo "$strIn" | grep 'Critical Warning:' >/dev/null; then
                    if [[ $increased != "yes" ]]; then
                        echo -e "${Yellow}$strIn${Off}"
                    fi
                elif echo "$strIn" | grep 'Temperature:' >/dev/null; then
                    if [[ $increased != "yes" ]]; then
                        echo -e "${Yellow}$strIn${Off}"
                    fi
                elif echo "$strIn" | grep 'Percentage Used:' >/dev/null; then
                    if [[ $increased != "yes" ]]; then
                        echo -e "${Yellow}$strIn${Off}"
                    fi
                elif echo "$strIn" | grep 'Power On Hours:' >/dev/null; then
                    if [[ $increased != "yes" ]]; then
                        echo -e "${Yellow}$strIn${Off}"
                    fi
                elif echo "$strIn" | grep 'Unsafe Shutdowns:' >/dev/null; then
                    if [[ $increased != "yes" ]]; then
                        echo -e "${Yellow}$strIn${Off}"
                    fi
                elif echo "$strIn" | grep 'Media and Data Integrity Errors:' >/dev/null; then
                    if [[ $increased != "yes" ]]; then
                        echo -e "${Yellow}$strIn${Off}"
                    fi
                else
                    if [[ $increased != "yes" ]]; then
                        echo "$strIn"
                    fi
                fi
            else
                # smartctl7 not installed
                if echo "$strIn" | grep 'data_units_' >/dev/null; then
                    # Get data_units read or written
                    units="$(echo "$strIn" | awk '{print $3}')"
                    # Remove commas and convert to TB/GB/MB
                    units_show="$(echo "${units//,}" | numfmt --to=si --suffix=B)"
                    # Show data_units read or written
                    if [[ $increased != "yes" ]]; then
                        echo "$strIn  ($units_show)"
                    fi
                elif echo "$strIn" | grep 'critical_warning' >/dev/null; then
                    if [[ $increased != "yes" ]]; then
                        echo -e "${Yellow}$strIn${Off}"
                    fi
                elif echo "$strIn" | grep 'temperature' >/dev/null; then
                    if [[ $increased != "yes" ]]; then
                        echo -e "${Yellow}$strIn${Off}"
                    fi
                elif echo "$strIn" | grep 'percentage_used' >/dev/null; then
                    if [[ $increased != "yes" ]]; then
                        echo -e "${Yellow}$strIn${Off}"
                    fi
                elif echo "$strIn" | grep 'power_on_hours' >/dev/null; then
                    if [[ $increased != "yes" ]]; then
                        echo -e "${Yellow}$strIn${Off}"
                    fi
                elif echo "$strIn" | grep 'unsafe_shutdowns' >/dev/null; then
                    if [[ $increased != "yes" ]]; then
                        echo -e "${Yellow}$strIn${Off}"
                    fi
                elif echo "$strIn" | grep 'media_errors' >/dev/null; then
                    if [[ $increased != "yes" ]]; then
                        echo -e "${Yellow}$strIn${Off}"
                    fi
                else
                    if [[ $increased != "yes" ]]; then
                        echo "$strIn"
                    fi
                fi
            fi
        done
        if [[ $smartversion -lt "7" ]]; then
            echo ""
        fi
    elif [[ $1 == "smart-log-add" ]]; then
        # Retrieve additional SMART Log
        nvme smart-log-add "/dev/$drive"    # Does not work
    elif [[ $1 == "self-test-log" ]]; then
        # Retrieve the SELF-TEST Log
        nvme self-test-log "/dev/$drive"    # Not used
    fi
}

short_attibutes_nvme(){ 
    # $1 is like "critical_warning"
    # $2 is "zero" or "none"
    # $3 is space padded attribute number like "  5" or "199"
    # $4 is attribute name with padding like "Unsafe_Shutdowns            "
    # $strIn is like "critical_warning                    : 0"
    if [[ "$strIn" ]]; then
        var1="$4"                                       # display string
        var2=$(echo "$strIn" | cut -d":" -f2 | xargs)   # value
        var3=$(echo "$4" | awk '{print $1}')            # name
        var4="$3"                                       # attribute number

        # Remove % from Percentage_Used
        #var2="${var2//%/}"  # Currently not used

        if [[ $2 == "zero" && "${var2:0:1}" -gt "0" ]]; then
            log_bad_nvme "$var3" "$var2"
            if [[ $increased != "yes" ]]; then
                echo -e "$var4 ${Yellow}$var1${Off} ${LiteRed}$var2${Off}$show_increased"
            elif [[ $first_run == "yes" ]]; then
                new_atts+=("$var4 ${Yellow}$var1${Off} ${LiteRed}$var2${Off}")
            else
                changed_atts+=("$var4 ${Yellow}$var1${Off} ${LiteRed}$var2${Off}$show_increased")
            fi
        elif [[  $2 == "none" && "${var2:0:1}" -gt "0" ]]; then
            if [[ $increased != "yes" ]]; then
                echo -e "$var4 $var1 $var2"
            fi
        else
            if [[ $increased != "yes" ]]; then
                echo -e "$var4 ${Yellow}$var1${Off} $var2"
            fi
        fi

        if [[ $var2 =~ ^[0-9]+$ ]]; then
            if [[ $2 == "zero" && $var2 -eq "0" ]]; then
                log_bad_nvme "$var3" "$var2"
            fi
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
            short_attibutes_nvme "critical_warning" zero "  1" "Critical_Warning            "
        elif [[ $nvme_att == "temperature" ]]; then
            # 2 Temperature - scrutiny
            short_attibutes_nvme "temperature" none "  2" "Temperature                 "
        elif [[ $nvme_att == "percentage_used" ]]; then
            # 5 Percentage Used
            short_attibutes_nvme "percentage_used" none "  5" "Percentage_Used             "
        elif [[ $nvme_att == "power_on_hours" ]]; then
            # 12 Power On Hours
            short_attibutes_nvme "power_on_hours" none " 12" "Power_On_Hours              "
        elif [[ $nvme_att == "unsafe_shutdowns" ]]; then
            # 13 Unsafe Shutdowns
            short_attibutes_nvme "unsafe_shutdowns" zero " 13" "Unsafe_Shutdowns            "
        elif [[ $nvme_att == "media_errors" ]]; then
            # 14 Media Errors
            short_attibutes_nvme "media_errors" zero " 14" "Media_Errors                "
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
    # Check if drive is Seagate or Seagate based Synology HAT3300
    DEVICE=$("$smartctl" -A -i /dev/"$drive" | awk -F ' ' '/Device Model/{print $3}')
    if [[ -z $DEVICE ]]; then
        DEVICE=$("$smartctl" -A -i /dev/"$drive" | awk -F ' ' '/Product/{print $2}')
    fi
    if [[ "${DEVICE:0:2}" == "ST" ]] || [[ "${DEVICE:0:7}" == "HAT3300" ]]; then
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


# Create smart.log file if needed
smart_log="${logpath}"/smart.log
if [[ ! -f $smart_log ]]; then
    touch "$smart_log"
    chown root:root "$smart_log"
    chmod 666 "$smart_log"
fi


# Sort HDD and SSD devices by DSM drive name
for drive in "${drives[@]}"; do
    get_drive_num
    drive_number="$(echo "$drive_num" | xargs)"

    if [[ ${#drive_number} == "7" ]]; then
        drives_1+=("${drive_number:?},${drive:?}")
    elif [[ ${#drive_number} == "8" ]]; then
        drives_2+=("${drive_number:?},${drive:?}")
    elif [[ ${#drive_number} == "9" ]]; then
        drives_3+=("${drive_number:?},${drive:?}")
    elif echo "$drive_number" | grep -q -E '^System Drive'; then
        sys_drives+=("${drive_number:?},${drive:?}")
    elif echo "$drive_number" | grep -q -E '\(DX|\(RX|\(FX'; then
        d_number="$(echo "$drive_num" | cut -d"(" -f1 | xargs)"
        if [[ ${#d_number} == "7" ]]; then
            eunit_drives_1+=("${drive_number:?},${drive:?}")
        elif [[ ${#d_number} == "8" ]]; then
            eunit_drives_2+=("${drive_number:?},${drive:?}")
        elif [[ ${#d_number} == "9" ]]; then
            eunit_drives_3+=("${drive_number:?},${drive:?}")
        fi
    fi
done

# Sort HDD/SSD drives_1 array
IFS=$'\n'
drives_sorted=($(sort <<<"${drives_1[*]}"))  # Sort array
unset IFS

# Sort HDD/SSD drives_2 array
IFS=$'\n'
drives_sorted_2=($(sort <<<"${drives_2[*]}"))  # Sort array
unset IFS

# Append drives_sorted_2 to drives_sorted
for d in "${drives_sorted_2[@]}"; do
    drives_sorted+=("$d")
done

# Sort HDD/SSD drives_3 array
IFS=$'\n'
drives_sorted_3=($(sort <<<"${drives_3[*]}"))  # Sort array
unset IFS

# Append drives_sorted_3 to drives_sorted
for d in "${drives_sorted_3[@]}"; do
    drives_sorted+=("$d")
done


# Sort HDD/SSD sys_drives array
IFS=$'\n'
sys_drives_sorted=($(sort <<<"${sys_drives[*]}"))  # Sort array
unset IFS

# Append sys_drives_sorted to drives_sorted
for d in "${sys_drives_sorted[@]}"; do
    drives_sorted+=("$d")
done


# Get array of connected expansion units
# Only device tree models have syno_slot_mapping so we use different method
for f in /tmp/eunitinfo_*; do
    if [[ -f "$f" ]]; then
        eunits+=("$(get_key_value "$f" EUnitModel)")
    fi
done

# Sort eunit HDD/SSD eunit_drives_1 array
IFS=$'\n'
eunit_drives_sorted=($(sort <<<"${eunit_drives_1[*]}"))  # Sort array
unset IFS

# Sort eunit HDD/SSD eunit_drives_2 array
IFS=$'\n'
eunit_drives_sorted_2=($(sort <<<"${eunit_drives_2[*]}"))  # Sort array
unset IFS

# Append eunit_drives_sorted_2 to eunit_drives_sorted
for d in "${eunit_drives_sorted_2[@]}"; do
    eunit_drives_sorted+=("$d")
done

# Sort eunit HDD/SSD eunit_drives_3 array
IFS=$'\n'
eunit_drives_sorted_3=($(sort <<<"${eunit_drives_3[*]}"))  # Sort array
unset IFS

# Append eunit_drives_sorted_3 to eunit_drives_sorted
for d in "${eunit_drives_sorted_3[@]}"; do
    eunit_drives_sorted+=("$d")
done

# Append eunit drives to drives_sorted in eunit order then drive number order
for e in "${eunits[@]}"; do
    for d in "${eunit_drives_sorted[@]}"; do
        if echo "$d" | grep -q "$e"; then
            drives_sorted+=("$d")
        fi
    done
done


# HDD and SSD
for d in "${drives_sorted[@]}"; do
    # Get drive from 'drive num,drive' in $d
    drive="${d#*,}"

    # Empty arrays
    changed_atts=()
    new_atts=()

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
        percentleft=$("$smartctl" -a -d "$drive_type" -T permissive /dev/"$drive" | grep "  Self-test routine in progress" | cut -d " " -f9-13)
        if [[ $percentleft ]]; then
            hourselapsed=$("$smartctl" -a -d "$drive_type" -T permissive /dev/"$drive" | grep "  Self-test routine in progress" | cut -d " " -f21)
            if [[ $increased != "yes" ]]; then
                echo "Drive $model $serial $percentleft remaining, $hourselapsed hours elapsed."
            fi
        else
            # Show drive health
            show_health
        fi
    else
        # DSM 6 or older

        # Show SMART test status if SMART test running
        percentdone=$("$smartctl" -a -d "$drive_type" -T permissive /dev/"$drive" | grep "ScanStatus" | cut -d " " -f3-4)
        if [[ $percentdone ]]; then
            hourselapsed=$("$smartctl" -a -d "$drive_type" -T permissive /dev/"$drive" | grep "  Self-test routine in progress" | cut -d " " -f21)
            if [[ $increased != "yes" ]]; then
                echo "Drive $model $serial ${percentdone}% done."
            fi
        else
            # Show drive health
            show_health
        fi
    fi

    if [[ $increased == "yes" ]]; then
        if [[ ${#changed_atts[@]} -gt "0" ]]; then
            if echo "${changed_atts[*]}" | grep -q -E 'Increased|Decreased'; then
                increased_count=$((increased_count +1))
                echo -e "$show_drive_info"
                for i in "${changed_atts[@]}"; do
                    if echo "$i" | grep -q -E 'Increased|Decreased'; then
                        echo -e "$i"
                    fi
                done
            fi
        fi
    fi

    if [[ $first_run == "yes" ]]; then
        if [[ ${#new_atts[@]} -gt "0" ]]; then
            increased_count=$((increased_count +1))
            echo -e "$show_drive_info"
            for i in "${new_atts[@]}"; do
                echo -e "$i"
            done
        fi
    fi
done


# Sort NVMe devices by DSM drive number and PCIe M.2 Card model
for drive in "${nvmes[@]}"; do
    get_nvme_num
    drive_number="$(echo "$drive_num" | xargs)"

    m2_card="$(synonvme --m2-card-model-get /dev/"$drive")"
    if echo "$m2_card" | grep -q 'Not M.2 adapter card'; then
        m2_card=""
        nvmes_temp+=("${drive_number:?},${drive:?}")
    else
        nvmes_card_temp+=("${drive_number:?} (${m2_card}),${drive:?}")
    fi
done

# Internal NVMe drives
IFS=$'\n'
nvmes_sorted=($(sort <<<"${nvmes_temp[*]}"))  # Sort array
unset IFS

# NVMe drives in PCIe M.2 cards
IFS=$'\n'
nvmes_card_sorted=($(sort <<<"${nvmes_card_temp[*]}"))  # Sort array
unset IFS

# Append nvmes_card_sorted to nvmes_sorted
for d in "${nvmes_card_sorted[@]}"; do
    nvmes_sorted+=("$d")
done

# NVMe drives
for d in "${nvmes_sorted[@]}"; do
    # Get drive_num and drive from 'drive num,drive' in $d
    drive_num="${d%%,*}  "  # Get contents of variable before comma
    drive="${d#*,}"         # Get contents of variable after comma

    # Empty the arrays
    changed_atts=()
    new_atts=()

    # Show drive model and serial
    #get_nvme_num  # Uncomment to hide PCIe M2 card model
    show_drive_model

    # Show SMART overall health if smartctl7 is installed
    if [[ $smartversion -gt "6" ]]; then
        strIn=$("$smartctl" -H /dev/"$drive" | grep 'health')
        if $(echo "$strIn" | grep -qi PASSED); then
            if [[ $increased != "yes" ]]; then
                echo -e "SMART overall-health self-assessment test result: ${LiteGreen}PASSED${Off}"
            fi
        elif $(echo "$strIn" | grep -qi 'Health Status: OK'); then
            if [[ $increased != "yes" ]]; then
                echo -e "SMART Health Status: ${LiteGreen}OK${Off}"
            fi
        else
            if [[ $increased != "yes" ]]; then
                echo "$strIn"
            fi
        fi
    fi

    smart_nvme error-log
    if [[ $errcount -gt "0" ]]; then
        errtotal=$((errtotal +errcount))
    fi

    # Show SMART attributes
    if [[ $errcount -gt "0" ]] || [[ $all == "yes" ]]; then
        # Show all SMART attributes if health != passed, or -a/--all option used
        smart_nvme smart-log        
    else
        # Show only important SMART attributes
        show_health_nvme
    fi

    if [[ $increased == "yes" ]]; then
        if [[ ${#changed_atts[@]} -gt "0" ]]; then
            if echo "${changed_atts[*]}" | grep -q -E 'Increased|Decreased'; then
                increased_count=$((increased_count +1))
                echo -e "$show_drive_info"
                for i in "${changed_atts[@]}"; do
                    if echo "$i" | grep -q -E 'Increased|Decreased'; then
                        echo -e "$i"
                    fi
                done
            fi
        fi
    fi

    if [[ $first_run == "yes" ]]; then
        if [[ ${#new_atts[@]} -gt "0" ]]; then
            increased_count=$((increased_count +1))
            echo -e "$show_drive_info"
            for i in "${new_atts[@]}"; do
                echo -e "$i"
            done
        fi
    fi
done

if [[ $increased == "yes" ]]; then
    if [[ -z $increased_count ]]; then
        echo -e "\n${LiteGreen}No drives have increased important SMART attributes${Off}"
        warn=""
        errtotal="0"
    elif [[ $first_run == "yes" ]]; then
        echo -e "\nThe above drives have important SMART attributes greater than zero"
        warn=""
        errtotal="0"
    fi
fi

# Show how long the script took
end="$SECONDS"
if [[ $debug == "yes" ]]; then
    if [[ $color != "no" ]]; then
        echo ""
        if [[ $end -ge 3600 ]]; then
            printf 'Duration: %dh %dm\n\n' $((end/3600)) $((end%3600/60))
        elif [[ $end -ge 60 ]]; then
            echo -e "Duration: $((end/60))m $((end%60))s"
        else
            echo -e "Duration: ${end} seconds"
        fi
    fi
fi

if [[ $color != "no" ]]; then
    echo -e "\nFinished\n"
else
    echo ""
fi

if [[ $warn -gt "0" ]]; then
    errtotal=$((errtotal +warn))
fi

exit "$errtotal"
