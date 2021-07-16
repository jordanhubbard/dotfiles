#!/bin/sh

# Customize to taste.  In my case, I like SantaClara2 and I am jordanh
DEF_VPN=SantaClara2
DEF_USER=jordanh

VPN_LIST="
London ngvpn10.vpn.nvidia.com
Wurselen ngvpn11.vpn.nvidia.com
Zurich ngvpn12.vpn.nvidia.com
Berlin ngvpn13.vpn.nvidia.com
Munich ngvpn14.vpn.nvidia.com
Moscow ngvpn16.vpn.nvidia.com
Helsinki ngvpn19.vpn.nvidia.com
Bangalore1 ngvpn20.vpn.nvidia.com
Bangalore2 ngvpn22.vpn.nvidia.com
Pune1 ngvpn21.vpn.nvidia.com
Pune2 ngvpn23.vpn.nvidia.com
Hyderabad ngvpn25.vpn.nvidia.com
HongKong ngvpn30.vpn.nvidia.com
Beijing ngvpn31.vpn.nvidia.com
Shanghai ngvpn32.vpn.nvidia.com
Shenzhen ngvpn33.vpn.nvidia.com
Taipei ngvpn34.vpn.nvidia.com
Hsinchu ngvpn35.vpn.nvidia.com
Seoul ngvpn36.vpn.nvidia.com
Tokyo ngvpn37.vpn.nvidia.com
SantaClara1 ngvpn01.vpn.nvidia.com
SantaClara2 ngvpn02.vpn.nvidia.com
Austin ngvpn03.vpn.nvidia.com
Durham ngvpn04.vpn.nvidia.com
Westford ngvpn05.vpn.nvidia.com
Redmond ngvpn06.vpn.nvidia.com
Beaverton ngvpn07.vpn.nvidia.com
Toronto ngvpn08.vpn.nvidia.com
StLouis ngvpn09.vpn.nvidia.com
Reno ngvpn50.vpn.nvidia.com
"

print_vpn_servers()
{
    odd=0
    for server in ${VPN_LIST}; do
	if [ $odd -eq 0 ]; then
	    echo "${server} \c"
	    odd=1
        else
	    odd=0
	    continue
        fi
    done
}

vpn_server_for_name()
{
    _found=0
    _hostname=""
    for server in ${VPN_LIST}; do
	if [ "$1" == "${server}" ]; then
	    _found=1
	    continue
	fi
        if [ $_found -eq 1 ]; then
	    _hostname=${server}
	    break
	fi
    done
    echo ${_hostname}
}

if [ $# -eq 0 ]; then
    _VPN=`vpn_server_for_name ${DEF_VPN}`
else
    while getopts hls:u: flag; do
	case "${flag}" in
	    h) echo "Usage: $0 [-h|-l|-s vpn-location|-u username]"
	       echo "Use -l to list all known vpn-locations"
	       echo "Use -s to select a specific vpn-location"
	       echo "Default behavior is to use ${DEF_VPN} location"
	       exit 0
	       ;;
	    
	    l) echo "Default VPN server: ${DEF_VPN}"
	       echo "Possible VPN servers:"
	       print_vpn_servers
	       echo
	       exit 0
	       ;;
	    
	    s)
		_VPN=`vpn_server_for_name ${OPTARG}`
		if [ -z "${_VPN}" ]; then
		    echo "Unable to find server ${OPTARG}. Use -l to list servers"
		    exit 1
		fi
		;;
	    
	    u)
		_USER=${OPTARG}
		;;
	esac
    done
fi

[ -z "${_USER}" ] && _USER=${DEF_USER}

_VPN_ARGS="--authgroup=Employee --user=${_USER} --servercert pin-sha256:9ax0WUN0h+NDlESAxoKF3K5rbby/RrYPTBtiz7ejgAU="

echo "Connecting to VPN server ${_VPN} - you will need to supply your password"
sudo openconnect ${_VPN} ${_VPN_ARGS}
