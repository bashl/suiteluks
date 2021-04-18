#!/bin/env sh

if [ "$EUID" -ne 0 ]; then
	echo "Execute como sudo"
	exit
else

#cores
verm='\033[0;31m'
semc='\033[0m'

echo "|------------------------------|"
echo "|                              |"
echo -e "|  ${verm}   Feito por um anônimo ${semc}    |"
echo "|                              |"
echo -e "|    ${verm}          Luks ${semc}           |"
echo "|                              |"
echo "|------------------------------|"


#lista os HD e formata o output
function pegarHDDS(){
	discos=$(lsblk -rpo "name,type,size,mountpoint" | awk '$4==""{printf "%s (%s) \n ",$1,$3}')
	echo $discos
}
#função base para encriptação guiada
function baseScriptNormal(){

	pegarHDDS
	echo "Digite o final do disco: (ex: sdc)"
	read driver
	#formata o input removendo números caso o usuário bote, necessário para o parted (não achei outro método)
	sanitizer=`echo $driver | sed 's/[0-9]*//g'`
	#formata o input para /dev/...
	disk=/dev/$sanitizer
	#mostra o tamanho do disco
	tamanho=$(fdisk -l | grep $disk | awk '{print $5}' | tail -n 1)
	echo "Você selecionou o HD: "$disk
	echo -e "${verm}ATENÇÃO: ISSO VAI EXCLUIR TODOS OS DADOS DO HD ${semc}"

}


#função base para encriptação particionada guiada
function baseScriptPart(){

	pegarHDDS
	echo "Digite o final do HD: (ex: sdc1)"
	read driver
	#formata o input para /dev/...
	disk=/dev/$driver
	#mostra o tamanho do disco
	tamanho=$(fdisk -l | grep $disk | awk '{print $5}' | tail -n 1)
	echo "Você selecionou o HD: "$disk
	echo -e "${verm}ATENÇÃO: ISSO VAI EXCLUIR TODOS OS DADOS DA PARTIÇÃO ${semc}"

}

#função para particionar
function partedGuided(){

	read particao
	sanitizerParted=`echo $particao | sed 's/[^0-9]*//g'`
	#conversão de GB para MB
	convert=$(bc <<< "$sanitizerParted * 953.67431640625")
	parted $disk mklabel gpt
	parted -a optimal $disk mkpart primary ext4 0% $convert
	#parted -a optimal $disk mkpart primary ext4 $convert 100%
	#remove a pontuação, certamente deve ter um jeito melhor para fazer esse hook
	#mas não consigo pensar em nada melhor agora
	convert=`echo $convert | sed 's/[*[:punct:]]//g'`

}

#encriptar com luks2
function encryptLuksNormal(){
	echo -e "${verm}ATENÇÃO: NÃO ESQUEÇA ESSE NOME ${semc}"
	echo "Qual nome você quer dar para o container? [cryptroot]"
	read nomeContainer
	[[ -z $nomeContainer ]] && nomeContainer="cryptroot" && echo -e "${verm}Usando o nome default 'cryptroot' ${semc}"
	echo "Inicializando LUKS..."
	cryptsetup luksFormat $disk
	echo "Digite a senha que você acabou de digitar: "
	cryptsetup luksOpen $disk $nomeContainer
	echo "Formatando container em ext4"
	mkfs.ext4 -j /dev/mapper/$nomeContainer
	mkdir -p /mnt/cts
	mount /dev/mapper/$nomeContainer /mnt/cts
	echo "Pronto! $nomeContainer está montado em /mnt/cts"

}

function urandomHookPart(){

	#queria fazer algo com for loop, mas não sei e achei mais voltada a error prone
	formatInputUrandom=$(lsblk -rpo "name,type,size,mountpoint" | grep /dev/${driver} | awk '$4==""{printf "%s (%s)\n",$1,$3}')
	echo $formatInputUrandom
	echo "Selecione a partição que você criou agora: (ex: sdc1) "
	read disk
	disk=/dev/$disk

	#prompt em loop de yes/no usando case opção particionada
while true; do
   echo "Você quer preencher o HD com dados aleátorios? Esse processo demora um pouco, mas aumenta a segurança "
   read yn
    case $yn in
        [Yy]* ) dd if=$disk of=/dev/urandom bs=1M count=$convert status=progress
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
function urandomHookNormal(){

	#prompt em loop de yes/no usando case opção normal
while true; do
    echo "Você quer preencher o HD com dados aleátorios? Esse processo demora um pouco, mas aumenta a segurança "
    read yn
    case $yn in
        [Yy]* ) dd if=/dev/$driver of=/dev/urandom bs=1M count=$tamanho status=progress
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



PS3="Escolha uma das opções abaixo: "
select opt in Criar 'Criar Particionado' Abrir Fechar Sair;
do
	case $opt in
	Criar)
		baseScriptNormal
		urandomHookNormal
		encryptLuksNormal
		break
		;;
	'Criar Particionado')
                baseScriptPart
		partedGuided
		urandomHookPart
		encryptLuksNormal
		break
		;;
	Abrir)
		pegarHDDS
		echo "Digite o final do HD: "
		read openHDD
		echo "Digite o nome do container: [cryptroot]"
		read openCont
		[[ -z $nomeContainer ]] && openCont="cryptroot"
		openForm=/dev/mapper/$openCont
		cryptsetup luksOpen /dev/$openHDD $openCont
		mount $openForm /mnt/cst
		echo "Pronto! Está montado em /mnt/cst"
		break
		;;
	Fechar)
		echo "Digite o nome do container: [cryptroot]"
		read openCont
		[[ -z $openCont ]] && openCont="cryptroot"
		openForm=/dev/mapper/$openCont
		umount $openForm
		cryptsetup luksClose $openCont
		echo "Pronto!"
		break
		;;
	Sair)
		break
		;;
	*)
		echo "Opção inválida"
esac
done
fi
