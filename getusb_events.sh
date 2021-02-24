#!/bin/bash

function setpath() 
{

export COLOR_NC='\e[0m'
export COLOR_RED='\e[0;31m'

if [ "${PROJECT_FILE_PATH}" = "$(pwd)/Processed_Info/$(cat ${mlocation}etc/hostname)_$(date +%d_%m_%Y)" ]
then
	USB_PATH=${PROJECT_FILE_PATH}/USB
	mkdir -p ${USB_PATH}
	mkdir -p "$(pwd)/Processed_Info/$(cat ${mlocation}etc/hostname)_$(date +%d_%m_%Y)/Reports"
	echo -e "USB event log are collected in ${COLOR_RED}${USB_PATH}${COLOR_NC} directory..\n"
else
#	echo "var not set"
	mkdir -p "$(pwd)/Processed_Info/$(cat ${mlocation}etc/hostname)_$(date +%d_%m_%Y)"
	PROJECT_FILE_PATH="$(pwd)/Processed_Info/$(cat ${mlocation}etc/hostname)_$(date +%d_%m_%Y)"
	USB_PATH=${PROJECT_FILE_PATH}/USB
	mkdir -p ${USB_PATH}
	mkdir -p "$(pwd)/Processed_Info/$(cat ${mlocation}etc/hostname)_$(date +%d_%m_%Y)/Reports"
	echo -e "USB event log are collected in ${COLOR_RED}${USB_PATH}${COLOR_NC} directory..\n"
fi

}


function checkmountpoint()
{

	if [ -n "$mlocation" ]
	then
		echo "Mount location is : $mlocation"
		echo
		sleep 2
	else
	        read -p "Enter the mount point location of /root/ for disk under investigation : " mlocation
        	#mlocation="/mnt/linux"
		if [ $mlocation = "/" ]
		then
			temp="/"
		else
			temp=$(echo "$mlocation" | sed 's/.$//')
		fi

	        df -h | grep -o "${temp}"  >/dev/null
        	checkpoint=$(echo $?)
	        if [ "$checkpoint" = "1" ]
        	then
                	echo "Mount point location does not found : $mlocation"
	                echo "Re-run the script with correct the mount location"
			sleep 1
        	        exit
	        fi
        	export mlocation
	        #cd $mlocation
	fi
}


function usb_info(){

USB_EVENTS="${PROJECT_FILE_PATH}"/Reports/usb_events.csv
#echo ${USB_EVENTS}
>"${USB_EVENTS}"


readarray -t conntime < <(grep -i -B8 'usb-storage' ${mlocation}var/log/messages* | grep -i 'mass' | awk '{ print $1, $2, $3}')
updated_conntime=()
uid=()

for ((i=0; i<$(echo ${#conntime[@]}); i++))
do 
	echo "${conntime[i]}" | grep -q '-'
	if  [ $? -eq 0 ]
	then
		a=$(echo "${conntime[i]}" | grep -o '\-[0-9]\{4\}' | grep -o '[0-9]\{4\}')
		b=$(echo "${conntime[i]}" | awk -F":" '{print $2":"$3":"$4}')
		c=$(date -d "$b" "+%m%d%H%M%S")
		updated_conntime[$i]=$(echo $a$c)
		uid[$i]=$(last -n 1 -t ${updated_conntime[$i]} | sed -n '1p' | awk '{print $1}')
			
	else
		a=$(date +%Y)
		b=$(echo "${conntime[i]}" | awk -F":" '{print $1":"$2":"$3}')
		c=$(date -d "$b" "+%m%d%H%M%S")
		updated_conntime[$i]=$(echo $a$c)
		uid[$i]=$(last -n 1 -t ${updated_conntime[$i]} | sed -n '1p' | awk '{print $1}')
	fi
done

#echo ${updated_conntime[@]}

readarray -t vid < <(grep -i -B8 'usb-storage' ${mlocation}var/log/messages* | awk -F"=" '/idVendor/{print $2}'| awk -F"," '{print $1}')
readarray -t pid < <(grep -i -B8 'usb-storage' ${mlocation}var/log/messages* | awk -F"=" '/idVendor/{print $3}'| awk -F"," '{print $1}')
readarray -t product < <(grep -i -B8 'usb-storage' ${mlocation}var/log/messages* | awk -F":" '/Product:/{print $NF}' | tr -d ' ')
readarray -t manufacturer < <(grep -i -B8 'usb-storage' ${mlocation}var/log/messages* | awk -F":" '/Manufacturer:/{print $NF}' | tr -d ' ')
readarray -t serialnum < <(grep -i -B8 'usb-storage' ${mlocation}var/log/messages* | awk -F":" '/SerialNumber:/{print $NF}' | tr -d ' ')
readarray -t port < <(grep -i -B8 'usb-storage' ${mlocation}var/log/messages* | awk '/idVendor/{print $7}' | awk -F":" '{print $1}')
readarray -t discontime < <(grep -i 'USB discon' ${mlocation}var/log/messages* | grep -i "$port" | awk '{ print $1, $2, $3}')

#echo ${discontime[@]}
updated_discontime=()

for ((i=0; i<$(echo ${#updated_conntime[@]}); i++))
do
	if [ -n "$(echo ${discontime[i]})" ]
	then 
		echo "${discontime[i]}" | grep -q '-'
		if  [ $? -eq 0 ]
		then
			a=$(echo "${discontime[i]}" | grep -o '\-[0-9]\{4\}' | grep -o '[0-9]\{4\}')
			b=$(echo "${discontime[i]}" | awk -F":" '{print $2":"$3":"$4}')
			c=$(date -d "$b" "+%m%d%H%M%S")
		
			updated_discontime[$i]=$(echo $a$c)	
		else
			a=$(date +%Y)
			b=$(echo "${discontime[i]}" | awk -F":" '{print $1":"$2":"$3}')
			c=$(date -d "$b" "+%m%d%H%M%S")
			updated_discontime[$i]=$(echo $a$c)
		fi
	else
                        updated_discontime[$i]=$(date +%Y%m%d%H%M%S)
	fi
done

#echo ${updated_discontime[@]}


for ((i=0; i<$(echo ${#conntime[@]}); i++))
do
	echo "${updated_conntime[i]},${product[i]},${manufacturer[i]},${serialnum[i]},${uid[i]},${updated_discontime[i]},${port[i]},${vid[i]},${pid[i]},HIGH">>${USB_EVENTS}
done

sed  -i '1i CONNECT_TIME,PRODUCTNAME,MANUFACTURER,SERIAL_NUMBER,USER,DISCONNECT_TIME,PORT,VENDOR_ID,PRODUCT_ID,RISK_RATING' ${USB_EVENTS}




#echo "connect_time:$conntime,vid=$vid,pid=$pid,productname=$product,serialnumber=$serialnum,port=$port,disconnect_time=$discontime"
}

function get_timeline_usbevents(){

#[ -d "usb" ] || mkdir usb

readarray -t START_TIME < <(awk -F"," 'NR>1{print $1}' ${USB_EVENTS} | sed 's/[0-9][0-9]$/\.&/g')
readarray -t END_TIME < <(awk -F"," 'NR>1{print $6}' ${USB_EVENTS} | sed 's/[0-9][0-9]$/\.&/g')
for ((i=0; i<$(echo ${#START_TIME[@]}); i++))
do
	touch -t "${START_TIME[i]}" /tmp/start 
	touch -t "${END_TIME[i]}" /tmp/stop
	
	find $mlocation -type f ! -path "${mlocation}proc/*" ! -path "${mlocation}sys/*" ! -path "*mozilla*"  -newer /tmp/start -not -newer /tmp/stop -printf "%M %u %g %TT %Td %Tm %TY %p\n" 2>/dev/null | sort -nk 7 -nk 6 -nk 5 -k 4 >${USB_PATH}/$(echo ${START_TIME[i]}_${END_TIME[i]}| sed 's/\.//g') 2>/dev/null

done
}

checkmountpoint
setpath
usb_info
get_timeline_usbevents


