# Synology SMART info

<a href="https://github.com/007revad/Synology_SMART_info/releases"><img src="https://img.shields.io/github/release/007revad/Synology_SMART_info.svg"></a>
![Badge](https://hitscounter.dev/api/hit?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_SMART_info&label=Visitors&icon=github&color=%23198754&message=&style=flat&tz=Australia%2FSydney)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/paypalme/007revad)
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/007revad)
<!-- [![committers.top badge](https://user-badge.committers.top/australia/007revad.svg)](https://user-badge.committers.top/australia/007revad) -->
<!-- [![committers.top badge](https://user-badge.committers.top/australia_public/007revad.svg)](https://user-badge.committers.top/australia_public/007revad) -->
<!-- [![committers.top badge](https://user-badge.committers.top/australia_private/007revad.svg)](https://user-badge.committers.top/australia_private/007revad) -->
<!-- [![Github Releases](https://img.shields.io/github/downloads/007revad/synology_smart_info/total.svg)](https://github.com/007revad/Synology_SMART_info/releases) -->

### Description

Show Synology smart test progress or smart health and attributes.

The script works in DSM 7, including DSM 7.2, DSM 7.3 and DSM 6.

In DSM 7.2.1 Synology removed the ability to view S.M.A.R.T. attributes in Storage Manager.

> **UPDATE** 
> v1.4.34 and later now decodes Seagate HDD and Synology HAT3300 HDD SMART values for attributes 1, 7, 195 and 240 with smartctl 6 or smartctl 7.

## Download the script

1. Download the latest version _Source code (zip)_ from https://github.com/007revad/Synology_SMART_info/releases
2. Save the download zip file to a folder on the Synology.
3. Unzip the zip file.

## How to run the script

### Run the script via SSH

[How to enable SSH and login to DSM via SSH](https://kb.synology.com/en-global/DSM/tutorial/How_to_login_to_DSM_with_root_permission_via_SSH_Telnet)

Run the script:

```bash
sudo -s /volume1/scripts/syno_smart_info.sh
```

> **Note** <br>
> Replace /volume1/scripts/ with the path to where the script is located.

To see all the SMART attributes run the script with the -a or --all option:

```bash
sudo -s /volume1/scripts/syno_smart_info.sh --all
```

> **Note** <br>
> The script automatically shows all SMART attributes for any drives that don't return "SMART test passed".

### Scheduling the script in Synology's Task Scheduler

See <a href=how_to_schedule.md/>How to schedule a script in Synology Task Scheduler</a>

### Options when running the script <a name="options"></a>

There are optional flags you can use when running the script:
```YAML
  -a, --all             Show all SMART attributes
  -e, --email           Disable colored text in output scheduler emails
  -i, --increased       Only show important attributes that have increased
  -u, --update          Update the script to the latest version
  -h, --help            Show this help message
  -v, --version         Show the script version
```

## Screenshots

<p align="center">All healthy</p>
<p align="center"><img src="/images/webber_wd.png"></p>

<p align="center">One drive marginal</p>
<p align="center"><img src="/images/oscar_seagate.png"></p>

<p align="center">UDMA CRC Errors</p>
<p align="center"><img src="/images/webber_udma_errors.png"></p>

<p align="center">NVMe drives removed while NAS was running</p>
<p align="center"><img src="/images/oscar_wd_nvme.png"></p>

<p align="center">SSD with reallocated sectors</p>
<p align="center"><img src="/images/senna.png"></p>

<p align="center">Run with --increased option</p>
<p align="center"><img src="/images/increased.png"></p>

<p align="center">HDD and SSD when run with --all option</p>
<p align="center"><img src="/images/hdd_ssd_all.png"></p>

<p align="center">HDD and NVMe when run with --all option</p>
<p align="center"><img src="/images/hdd_nvme_all.png"></p>
