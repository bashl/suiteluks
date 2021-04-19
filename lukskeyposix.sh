#!/bin/env sh

if [ "$(id -u)" -ne 0 ]; then
    echo "Execute como sudo"
    exit
else

echo
printf "|----------------------------|\n"
printf "|                            |\n"
printf "|\033[0;31m    Feito por um anônimo\033[0m    |\n"
printf "|                            |\n"
printf "|            \033[0;31mLuks\033[0m            |\n"
printf "|                            |\n"
printf "|----------------------------|\n"

pegarHDDS(){

    discos=$(lsblk -rpo "name,type,size,mountpoint" | awk '$4==""{printf "%s (%s) \n ",$1,$3}')
    echo "$discos"
}

finalHook(){

	pegarHDDS
	echo "Digite o final do HD onde se encontra container: (ex:sda2)"
	read -r inputHDD
	[ -n "$inputHDD" ] || echo "Digite o HD"
	diskFormat=/dev/"$inputHDD"
	checkHDD=$(lsblk -rpo "name,type,size,mountpoint" | grep "$diskFormat" | awk '$4==""{printf "%s\n",$1}')
	#teste para ver se existe o HD
	[ "$diskFormat" = "$checkHDD" ] || echo "HD não encontrado"

}

openCont(){

			echo "Digite o nome do container: "
			read -r openCont

}

criarChaveHook(){
	while true; do
		printf "Se você quer um arquivo(imagem, vídeo e etc) como chave, digite \033[0;31marq\033[0m, se quer uma senha aleátoria, digite \033[0;31msenha\033[0m: \n"
		read -r yn
		case "$yn" in
			[arq]* )
				echo "Digite o caminho absoluto do arquivo: "
				read -r arquivo
				[ -f "$arquivo" ] && echo "Arquivo foi encontrado" || echo "Arquivo não foi encontrado"
				echo "Adcionando o arquivo ($arquivo) como chave"
				finalHook
				printf "Adcionando o arquivo (%s) como chave do container \033[0;31m(%s)\033[0m\n" "$arquivo" "$diskFormat"
				echo "Logo em seguida será solicitado sua senha do container"
				cryptsetup luksAddKey "$diskFormat" "$arquivo"
				echo "Pronto"
				break
				;;
			[senha]* )
				echo "Escolha o diretório que você quer botar a chave (pode ser um pendrive ou local): "
				read -r pathChave
				[ -e "$pathChave" ] || echo "Diretório não encontrado"
				echo "Você quer dar um nome para a chave? [compras]"
				read -r nomeArquivo
				[ -z "$nomeArquivo" ] && nomeArquivo="compras"
				echo "Criando a chave..."
				touch "$pathChave"/"$nomeArquivo"
				fullPath="$pathChave"/"$nomeArquivo"
				dd bs=512 count=4 if=/dev/random of="$fullPath" iflag=fullblock
				echo "Alterando as permissões da chave..."
				[ -f "$fullPath" ] && chmod 600 "$fullPath"
				finalHook
				printf "Adcionando a chave \033[0;31m (%s) \033[0m como chave do container \033[0;31m (%s) \033[0m\n" "$fullPath" "$diskFormat"
				echo "Logo em seguida será solicitado sua senha do container"
				cryptsetup luksAddKey "$diskFormat" "$fullPath"
				echo "Pronto"
				break
				;;
		esac
	done

}

hookLuksDump(){

		dumpLuks2=$(cryptsetup luksDump "$diskFormat" | grep luks2)
		dumpKey=$(cryptsetup luksDump "$diskFormat" | grep 'Key Slot')
		[ -n "$dumpLuks2" ] && echo "$dumpLuks2" || echo "$dumpKey"

}

echo
printf "\033[0;31mATENÇÃO: Só use esse script se já tiver um container\033[0m\n"

helpMenu(){

	echo
	echo "SuiteLuks - POSIX Edition"
	echo
	echo "Opções: "
	echo " --help           Mostra esse menu"
	echo " --criar          Para adcionar uma chave a um container"
	echo " --abrir          Para abrir um container com uma chave"
	echo " --checar         Para checar chaves existentes no container"
	echo " --remover        Para remover uma chave existente"
	echo
}

if [ "$1" = "--help" ]
then

	helpMenu
	exit

elif [ "$1" = "--criar" ]
then
	criarChaveHook
	exit
elif [ "$1" = "--abrir" ]
then
	finalHook
	echo "Digite o caminho absoluto da chave: "
	read -r pathChave
	[ -f "$pathChave" ] || echo "Arquivo não foi encontrado"
	openCont
	cryptsetup luksOpen "$diskFormat" "$openCont" --key-file "$pathChave"
	openForm=/dev/mapper/"$openCont"
	mount "$openForm" /mnt/cst
	echo "Pronto! Está montado em /mnt/cst"
	exit

elif [ "$1" = "--checar" ]
then
	finalHook
	hookLuksDump
	exit

elif [ "$1" = "--remover" ]
then
	finalHook
	openCont
	hookLuksDump
	echo "Digite qual chave você quer excluir: [01]"
	read -r excluirChave
	[ -z "$excluirChave" ] && excluirChave="01"
	echo "Deletando a chave..."
	echo "Logo em seguida será solicitado a senha do container"
	cryptsetup luksKillSlot "$diskFormat" -S "$excluirChave"

else
	helpMenu
	exit

fi

fi #check sudo
