#!/bin/bash
#########################################################################
# Script:       check_omping.sh
# Purpose:      Monitoring plugin to monitor multicast communication using omping
# Get omping:   https://github.com/troglobit/omping
# License:      GNU General Public License (GPL) Version 2
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <https://www.gnu.org/licenses/>.
#
# Copyright 2020 Claudio Kuenzler
#
# History:
# 2020-03-21    First version / public release
#########################################################################
omping=/usr/bin/omping
port=9999
warn=80
crit=90
timeout=10
count=10
local_ip=$(hostname -I)
#########################################################################
help="check_omping.sh (c) 2020 Claudio Kuenzler\n
Usage: $0 -H targetIP [-p port] [-l localIP] [-o /path/to/omping] [-w warnpercent] [-c critpercent] [-t timeout] [-c count]\n
Example: $0 -H 10.10.50.30 -p 9999 -l 192.168.10.10 -o /usr/local/omping -w 80 -c 90"
#########################################################################
# Get user-given variables
while getopts "H:p:l:o:w:c:" Input;
do
       case ${Input} in
       H)      host=${OPTARG};;
       p)      port=${OPTARG};;
       l)      local_ip=${OPTARG};;
       o)      omping=${OPTARG};;
       w)      warn=${OPTARG};;
       c)      crit=${OPTARG};;
       *)      echo -e $help
               exit $STATE_UNKNOWN
               ;;
       esac
done
#########################################################################
# Did user obey to usage?
if [ -z $host ]; then echo -e $help; exit ${STATE_UNKNOWN}; fi
#########################################################################
# Pre-checks
if [[ ! -x $omping ]]; then echo "CRITICAL - $omping not found/not executable"; fi
if [ -z $local_ip ] || [ $local_ip == "" ]; then echo "UNKNOWN - local ip not defined"; fi
#########################################################################
output="$($omping -p ${port} -qq -c ${count} -O client -T ${timeout} ${local_ip} ${host})"

if [[ "$output" =~ "never received" ]]; then
        # We got no connection to the target
        echo "CRITICAL - response message from ${target} never received (timeout)"; exit 2
elif [[ "$output" =~ "unicast" ]]; then
        # We got a summary response
        # 10.10.50.30 :   unicast, xmt/rcv/%loss = 10/10/0%, min/avg/max/std-dev = 5.812/6.041/6.295/0.164
        # 10.10.50.30 : multicast, xmt/rcv/%loss = 10/0/100%, min/avg/max/std-dev = 0.000/0.000/0.000/0.000
        unicast_loss=$(echo "$output" | awk '/unicast/ {print $6}' | awk -F '/' '{print $3}' | sed 's/[^0-9]//g')
        multicast_loss=$(echo "$output" | awk '/multicast/ {print $6}' | awk -F '/' '{print $3}' | sed 's/[^0-9]//g')

        if [[ $multicast_loss -gt $crit ]]; then
                echo "CRITICAL - Multicast package loss to ${host} is ${multicast_loss}%|multicast_loss=${multicast_loss}%;80;90;0;100 unicast_loss=${unicast_loss}%;80;90;0;100"; exit 2
        elif [[ $multicast_loss -gt $warn ]]; then
                echo "WARNING - Multicast package loss to ${host} is ${multicast_loss}%|multicast_loss=${multicast_loss}%;80;90;0;100 unicast_loss=${unicast_loss}%;80;90;0;100"; exit 2
        elif [[ $multicast_loss -eq 0 ]]; then
                echo "OK - Multicast package loss to ${host} is ${multicast_loss}%|multicast_loss=${multicast_loss}%;80;90;0;100 unicast_loss=${unicast_loss}%;80;90;0;100"; exit 0
        fi

else
        echo "CRITICAL - no output received from omping"; exit 2
fi

echo "Should never reach this part"; exit 3
