#!/bin/env sh

if [ "$(id -u)" -ne 0 ]; then
	echo "Execute como sudo"
	exit
else

printf "|----------------------------|\n"
printf "|                            |\n"
printf "|\033[0;31m    Feito por um anônimo\033[0m    |\n"
printf "|                            |\n"
printf "|            \033[0;31mLuks\033[0m            |\n"
printf "|                            |\n"
printf "|----------------------------|\n"


#lista os HD e formata o output
pegarHDDS(){
	discos=$(lsblk -rpo "name,type,size,mountpoint" | awk '$4==""{printf "%s (%s) \n ",$1,$3}')
	echo "$discos"
}
#função base para encriptação guiada
baseScriptNormal(){

	pegarHDDS
	echo "Digite o final do disco: (ex: sdc)"
	read -r driver
	#formata o input removendo números caso o usuário bote, necessário para o parted (não achei outro método)
	sanitizer=$(echo "$driver" | sed 's/[0-9]*//g')
	#formata o input para /dev/...
	disk=/dev/"$sanitizer"
	#mostra o tamanho do disco
	tamanho=$(fdisk -l | grep "$disk" | awk '{print $5}' | tail -n 1)
	echo "Você selecionou o HD: ""$disk"
	printf "\033[0;31ATENÇÃO: ISSO VAI EXCLUIR TODOS OS DADOS DO HD\033[0m\n"

}


#função base para encriptação particionada guiada
baseScriptPart(){

	pegarHDDS
	echo "Digite o final do HD: (ex: sdc1)"
	read -r driver
	#formata o input para /dev/...
	disk=/dev/"$driver"
	#mostra o tamanho do disco
	tamanho=$(fdisk -l | grep "$disk" | awk '{print $5}' | tail -n 1)
	echo "Você selecionou o HD: ""$disk"
	printf "\033[0;31ATENÇÃO: ISSO VAI EXCLUIR TODOS OS DADOS DO HD\033[0m\n"

}

#função para particionar
partedGuided(){

	read -r particao
	sanitizerParted=$(echo "$particao" | sed 's/[^0-9]*//g')
	#conversão de GB para MB
	convert=$(echo "$sanitizerParted"*953.67431640625 | bc)
	parted "$disk" mklabel gpt
	parted -a optimal "$disk" mkpart primary ext4 0% "$convert"
	#parted -a optimal "$disk" mkpart primary ext4 $convert 100%

	#remove a pontuação, certamente deve ter um jeito melhor
	#para fazer esse hook
	#mas não consigo pensar em nada melhor agora
	convert=$(echo "$convert" | sed 's/[*[:punct:]]//g')

}

#encriptar com luks2
encryptLuksNormal(){
	printf "\033[0;31ATENÇÃO: NÃO ESQUEÇA ESSE NOME\033[0m\n"
	echo "Qual nome você quer dar para o container? [cryptroot]"
	read -r nomeContainer
	[ -z "$nomeContainer" ] && nomeContainer="cryptroot" && echo "Usando o nome default 'cryptroot'"
	echo "Inicializando LUKS..."
	cryptsetup luksFormat "$disk"
	echo "Digite a senha que você acabou de digitar: "
	cryptsetup luksOpen "$disk" "$nomeContainer"
	echo "Formatando container em ext4"
	mkfs.ext4 -j /dev/mapper/"$nomeContainer"
	mkdir -p /mnt/cts
	mount /dev/mapper/"$nomeContainer" /mnt/cts
	echo "Pronto! $nomeContainer está montado em /mnt/cts"

}

urandomHookPart(){

	#queria fazer algo com for loop, mas não sei e achei mais voltada a error prone
	formatInputUrandom=$(lsblk -rpo "name,type,size,mountpoint" | grep /dev/"${driver}" | awk '$4==""{printf "%s (%s)\n",$1,$3}')
	echo "$formatInputUrandom"
	echo "Selecione a partição que você criou agora: (ex: sdc1) "
	read -r disk
	disk=/dev/"$disk"

	#prompt em loop de yes/no usando case opção particionada
while true; do
   echo "Você quer preencher o HD com dados aleátorios? Esse processo demora um pouco, mas aumenta a segurança "
   read -r yn
    case $yn in
        [Yy]* ) dd if="$disk" of=/dev/urandom bs=1M count="$convert" status=progress
		echo "Pronto"
		break
		;;
        [Nn]* )
		break
		;;
        * )
		echo "Responda y ou n."
		;;
    esac
done

}
urandomHookNormal(){

	#prompt em loop de yes/no usando case opção normal
while true; do
    echo "Você quer preencher o HD com dados aleátorios? Esse processo demora um pouco, mas aumenta a segurança "
    read -r yn
    case $yn in
        [Yy]* ) dd if=/dev/"$driver" of=/dev/urandom bs=1M count="$tamanho" status=progress
		echo "Pronto"
		break
		;;
        [Nn]* )
		break
		;;
        * )
		echo "Responda y ou n."
		;;
    esac
done

}

helpMenu(){

	echo
	echo "SuiteLuks - POSIX Edition"
	echo
	echo "Opções: "
	echo " --help          Mostra esse menu"
	echo " --criar         Para criar container no HD inteiro"
	echo " --criarpart     Para criar container particionado"
	echo " --abrir         Abrir container"
	echo " --fechar        Fechar container"
	echo


}




if [ "$1" = "--help" ]
then
	helpMenu
	exit

elif [ "$1" = "--criar" ]
then
	baseScriptNormal
	urandomHookNormal
	encryptLuksNormal
	exit

elif [ "$1" = "--criarpart" ]
then
	baseScriptPart
	partedGuided
	urandomHookPart
	encryptLuksNormal
	exit

elif [ "$1" = "--abrir" ]
then
	pegarHDDS
	echo "Digite o final do HD: "
	read -r openHDD
	echo "Digite o nome do container: [cryptroot]"
	read -r openCont
	[ -z "$nomeContainer" ] && openCont="cryptroot"
	openForm=/dev/mapper/"$openCont"
	cryptsetup luksOpen /dev/"$openHDD" "$openCont"
	mount "$openForm" /mnt/cst
	echo "Pronto! Está montado em /mnt/cst"
	exit

elif [ "$1" = "--fechar" ]
then
	echo "Digite o nome do container: [cryptroot]"
	read -r openCont
	[ -z "$openCont" ] && openCont="cryptroot"
	openForm=/dev/mapper/"$openCont"
	umount "$openForm"
	cryptsetup luksClose "$openCont"					   echo "Pronto!"
	exit

else
	helpMenu
	exit
fi


fi
