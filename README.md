# Synology_SMART_info

<a href="https://github.com/007revad/Synology_SMART_info/releases"><img src="https://img.shields.io/github/release/007revad/Synology_SMART_info.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_SMART_info&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=views&edge_flat=false"/></a>
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/paypalme/007revad)
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/007revad)
[![committers.top badge](https://user-badge.committers.top/australia/007revad.svg)](https://user-badge.committers.top/australia/007revad)
<!-- [![committers.top badge](https://user-badge.committers.top/australia_public/007revad.svg)](https://user-badge.committers.top/australia_public/007revad) -->
<!-- [![committers.top badge](https://user-badge.committers.top/australia_private/007revad.svg)](https://user-badge.committers.top/australia_private/007revad) -->
<!-- [![Github Releases](https://img.shields.io/github/downloads/007revad/synology_smart_info/total.svg)](https://github.com/007revad/Synology_SMART_info/releases) -->

### Description

Show Synology smart test progress or smart health and attributes.

The script works in DSM 7, including DSM 7.2, and DSM 6.

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

## Screenshots

<p align="center">Clearing critical error for 2 drives</p>
<p align="center"><img src="/images/script-4.png"></p>


