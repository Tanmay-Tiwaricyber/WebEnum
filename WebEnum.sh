#!/bin/bash

echo "#     #                 #######"
echo "#  #  #  ######  #####  #        #    #  #    #  #    #"
echo "#  #  #  #       #    # #        ##   #  #    #  ##  ##"
echo "#  #  #  #####   #####  #####    # #  #  #    #  # ## #"
echo "#  #  #  #       #    # #        #  # #  #    #  #    #"
echo "#  #  #  #       #    # #        #   ##  #    #  #    #"
echo " ## ##   ######  #####  #######  #    #   ####   #    #"
printf "\e[1;77m\e[45m  WebEnum Version 1.0 Author: shadowXg   \e[0m\n"
printf "\n"

echo "Enter Target IP >>"
read ip
echo "Enter output File location for nmap scan >> "
read output
echo "Runnning Nmap.."
nmap -T4 -A -vv -oA $output -sV -O  $ip | lolcat
echo "running nmap --script vuln scan"
nmap --script vuln -oA $output $ip


echo "Enter IP or website url without http:// or https:// >> "
read ip
echo "What kind of website you are enumerating for directory 'http' or 'https' type >> "
read service
echo "Running Dirbuster.."
echo "Using dafault wordlist.."
echo "if you want to use another wordlist select option : '1' for entering new wordlist or '2' for continue >>"
read condition
if  [[  $condition == 1  ]]
then 
	echo "Enter directory for wordlist"
	read dir
	gobuster dir -t 10 -w $dir -v -u $ip
elif  [[  $condition == 2  ]]
then
	gobuster dir -t 10 -w /usr/share/dirb/wordlists/common.txt -u $service://$ip
else
	echo " !! Unexpected error !! " 
fi
#MG Hacker's Tool for enumerating website 
#doing nmap and dir scans






