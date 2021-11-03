#!/bin/sh

# Customize to taste.  In my case, I like SantaClara2 and I am jordanh
DEF_VPN="SantaClara3"
DEF_USER="jordanh"
VPN_SLICE="y"

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
SantaClara3 ngvpn50.vpn.nvidia.com
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
	if [ "$1" = "${server}" ]; then
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

usage()
{
    echo "Usage: $0 [-h|-l|-n|-s vpn-location|-u username]"
    echo "-h for this help text"
    echo "-l to list all known vpn-locations"
    echo "-n do not enable VPN domain slicing"
    echo "-s to select a specific vpn-location"
    echo "Default behavior is to use ${DEF_VPN} location"
    exit 0
}

VPN_HOST=`vpn_server_for_name ${DEF_VPN}`

while getopts "hlns:u:" flag; do
    case "${flag}" in
	h) usage
	   ;;
	    
	l) echo "Default VPN server: ${DEF_VPN}"
	   echo "Possible VPN servers:"
	   print_vpn_servers
	   echo
	   exit 0
	   ;;

	n) VPN_SLICE="n"
	   ;;

	s) VPN_HOST=`vpn_server_for_name ${OPTARG}`
	   if [ -z "${VPN_HOST}" ]; then
	       echo "Unable to find server ${OPTARG}. Use -l to list servers"
	       exit 1
	   fi
	   ;;
	    
	u) _USER=${OPTARG}
	   ;;

	*) usage
	   ;;
    esac
done

[ -z "${_USER}" ] && _USER=${DEF_USER}

# vpn-slice is a prerequsite for using this without the -n flag.  Easiest is to
# sudo pip3 install https://github.com/dlenski/vpn-slice/archive/master.zip

if [ "${VPN_SLICE}" = "n" ]; then
   VPN_ARGS="--authgroup=Employee -u ${_USER}"
else
   VPN_ARGS="-s 'vpn-slice --verbose --dump -I -i --domains-vpn-dns=nvidia.com,nvmetal.net %10.11.0.0/16 10.0.0.0/8 72.25.64.0/18 216.228.112.0/20 209.66.87.0/24 24.51.0.0/19 64.125.39.0/24 mail wiki confluence gpuwa nvinfo nvbugs nvbugswb prestige hqnvwa11 hqnvwa12 ssogate nvsso ssoauth teams dlrequest p4protects coupa vpn.nvidia.com apps.nvinfo.nvidia.com pid pdp services gitlab-master sapdctabl1 sape7psys sape7pscs docusign prom nv nvsearch psgview p4viewer view stg.vault.nvidia.com prod.vault.nvidia.com ngc' --authgroup=Employee -u ${_USER}"
fi

echo "Connecting to VPN server ${VPN_HOST} - you will need to supply your password"
eval sudo openconnect ${VPN_HOST} ${VPN_ARGS}
