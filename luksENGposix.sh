#!/bin/env sh

if [ "$(id -u)" -ne 0 ]; then
	echo "Run as sudo"
	exit
else

printf "|----------------------------|\n"
printf "|                            |\n"
printf "|\033[0;31m    Made by bashl       \033[0m    |\n"
printf "|                            |\n"
printf "|            \033[0;31mLuks\033[0m            |\n"
printf "|                            |\n"
printf "|----------------------------|\n"

#echo all hard drive and format the output
pegarHDDS(){
	discos=$(lsblk -rpo "name,type,size,mountpoint" | awk '$4==""{printf "%s (%s) \n ",$1,$3}')
	echo "$discos"
}
#function for guided encryption
baseScriptNormal(){

	pegarHDDS
	echo "Type the end of the hard disk: (ex: sdc)"
	read -r driver
	#sanitze the input if the user insert any number, necessary for parted (couldn't find another method)
	sanitizer=$(echo "$driver" | sed 's/[0-9]*//g')
	#format the input to /dev/...
	disk=/dev/"$sanitizer"
	#show space in hard drive
	tamanho=$(fdisk -l | grep "$disk" | awk '{print $5}' | tail -n 1)
	echo "You've selected: ""$disk"
	printf "\033[0;31WARNING: THIS WILL DELETE EVERYTHING\033[0m\n"

}

#base function for guided parted encryption
baseScriptPart(){

	pegarHDDS
	echo "Type the end of the hard disk: (ex: sdc1)"
	read -r driver
	#format the input to /dev/...
	disk=/dev/"$driver"
	#show space in the hard drive
	tamanho=$(fdisk -l | grep "$disk" | awk '{print $5}' | tail -n 1)
	echo "You've selected: ""$disk"
	printf "\033[0;31WARNING: THIS WILL DELETE EVERYTHING\033[0m\n"

}

#parted function
partedGuided(){

	read -r particao
	sanitizerParted=$(echo "$particao" | sed 's/[^0-9]*//g')
	#GB to MB conversion
	convert=$(echo "$sanitizerParted"*953.67431640625 | bc)
	parted "$disk" mklabel gpt
	parted -a optimal "$disk" mkpart primary ext4 0% "$convert"
	#parted -a optimal "$disk" mkpart primary ext4 $convert 100%

	#remove all the pontuation which the conversion have made
	#couldn't think another way
	convert=$(echo "$convert" | sed 's/[*[:punct:]]//g')

}

#function encryption with luks2
encryptLuksNormal(){
	printf "\033[0;31WARNING: DON'T FORGET THIS NAME\033[0m\n"
	echo "Which name do you want to give for the container? [cryptroot]"
	read -r nomeContainer
	[ -z "$nomeContainer" ] && nomeContainer="cryptroot" && echo "Using the default 'cryptroot'"
	echo "Initializing LUKS..."
	cryptsetup luksFormat "$disk"
	echo "Type the password you just gave for the container: "
	cryptsetup luksOpen "$disk" "$nomeContainer"
	echo "Formating the container in ext4"
	mkfs.ext4 -j /dev/mapper/"$nomeContainer"
	mkdir -p /mnt/cts
	mount /dev/mapper/"$nomeContainer" /mnt/cts
	echo "Everything settled! $nomeContainer is mounted in /mnt/cts"

}

urandomHookPart(){
	# I wanted to make something with loop, but found more error prone
	formatInputUrandom=$(lsblk -rpo "name,type,size,mountpoint" | grep /dev/"${driver}" | awk '$4==""{printf "%s (%s)\n",$1,$3}')
	echo "$formatInputUrandom"
	echo "Select the partition you just create: (ex: sdc1) "
	read -r disk
	disk=/dev/"$disk"

while true; do
   echo "Do you want to fill the whole hard disk with random data? This process can take a little bit but can increase security"
   read -r yn
    case $yn in
        [Yy]* ) dd if="$disk" of=/dev/urandom bs=1M count="$convert" status=progress
		echo "Everything settled"
		break
		;;
        [Nn]* )
		break
		;;
        * )
		echo "Answer with y or n."
		;;
    esac
done

}

# This is different from the above because it uses the whole hard disk.
urandomHookNormal(){

	#prompt em loop de yes/no usando case opção normal
while true; do
    echo "Do you want to fill the whole hard disk with random data? This process can take a little bit but can increase security"
    read -r yn
    case $yn in
        [Yy]* ) dd if=/dev/"$driver" of=/dev/urandom bs=1M count="$tamanho" status=progress
		echo "Everything settled"
		break
		;;
        [Nn]* )
		break
		;;
        * )
		echo "Answer with y or n."
		;;
    esac
done

}

helpMenu(){

	echo
	echo "SuiteLuks - POSIX Edition"
	echo
	echo "Options: "
	echo " --help           Show this help"
	echo " --create         To create a container using the whole disk"
	echo " --createpart     To create a particioned container"
	echo " --open           Open container"
	echo " --close          Close container"
	echo


}




if [ "$1" = "--help" ]
then
	helpMenu
	exit

elif [ "$1" = "--create" ]
then
	baseScriptNormal
	urandomHookNormal
	encryptLuksNormal
	exit

elif [ "$1" = "--createpart" ]
then
	baseScriptPart
	partedGuided
	urandomHookPart
	encryptLuksNormal
	exit

elif [ "$1" = "--open" ]
then
	pegarHDDS
	echo "Type the end of the HD: "
	read -r openHDD
	echo "Type the name of the container: [cryptroot]"
	read -r openCont
	[ -z "$nomeContainer" ] && openCont="cryptroot"
	openForm=/dev/mapper/"$openCont"
	cryptsetup luksOpen /dev/"$openHDD" "$openCont"
	mount "$openForm" /mnt/cst
	echo "Everything settled! It's mounted in /mnt/cst"
	exit

elif [ "$1" = "--close" ]
then
	echo "Type the name of the container: [cryptroot]"
	read -r openCont
	[ -z "$openCont" ] && openCont="cryptroot"
	openForm=/dev/mapper/"$openCont"
	umount "$openForm"
	cryptsetup luksClose "$openCont"
	echo "Everything settled!"
	exit

else
	helpMenu
	exit
fi


fi
