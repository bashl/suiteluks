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
echo -e "|    ${verm}      Suite Luks ${semc}         |"
echo "|                              |"
echo "|------------------------------|"

function pegarHDDS(){

    discos=$(lsblk -rpo "name,type,size,mountpoint" | awk '$4==""{printf "%s (%s) \n ",$1,$3}')
    echo $discos
}

function finalHook(){

	pegarHDDS
	echo "Digite o final do HD onde se encontra container: (ex:sda2)"
	read inputHDD
	[[ -n $inputHDD ]] || echo "Digite o HD"
	diskFormat=/dev/$inputHDD
	checkHDD=$(lsblk -rpo "name,type,size,mountpoint" | grep $diskFormat | awk '$4==""{printf "%s\n",$1}')
	#teste para ver se existe o HD
	[[ $diskFormat == $checkHDD ]] || echo "HD não encontrado"

}

function openCont(){

			echo "Digite o nome do container: "
			read openCont

}

function criarChaveHook(){
	while true; do
		echo -e "Se você quer um arquivo(imagem, vídeo e etc) como chave, digite ${verm}arq${semc}, se quer uma senha aleátoria, digite ${verm}senha${semc}: "
		read yn
		case $yn in
			[arq]* )
				echo "Digite o caminho absoluto do arquivo: "
				read arquivo
				[[ -f $arquivo ]] && echo "Arquivo foi encontrado" || echo "Arquivo não foi encontrado"
				echo "Adcionando o arquivo ($arquivo) como chave"
				finalHook
				echo -e "Adcionando o arquivo ($arquivo) como chave do container ${verm}($diskFormat)${semc}"
				echo "Logo em seguida será solicitado sua senha do container"
				cryptsetup luksAddKey $diskFormat $arquivo
				echo "Pronto"
				break
				;;
			[senha]* )
				echo "Escolha o diretório que você quer botar a chave (pode ser um pendrive ou local): "
				read pathChave
				[[ -e $pathChave ]] || echo "Diretório não encontrado"
				echo "Você quer dar um nome para a chave? [compras]"
				read nomeArquivo
				[[ -z $nomeArquivo ]] && nomeArquivo="compras"
				echo "Criando a chave..."
				touch $pathChave/$nomearquivo
				fullPath=$pathChave/$nomeArquivo
				dd bs=512 count=4 if=/dev/random of=$fullPath iflag=fullblock
				echo "Alterando as permissões da chave..."
				[[ -f $fullPath ]] && chmod 600 $fullPath
				finalHook
				echo -e "Adcionando a chave (${verm}$fullPath${semc}) como chave do container (${verm}$diskFormat${semc})"
				echo "Logo em seguida será solicitado sua senha do container"
				cryptsetup luksAddKey $diskFormat $fullPath
				echo "Pronto"
				break
				;;
		esac
	done

}

function hookLuksDump(){

		dumpLuks2=$(cryptsetup luksDump $diskFormat | grep luks2)
		dumpKey=$(cryptsetup luksDump $diskFormat | grep 'Key Slot')
		[[ -n $dumpLuks2 ]] && echo "$dumpLuks2" || echo "$dumpKey"

}


echo -e " ${verm}ATENÇÃO: Só use esse script se já tiver um container ${semc}"
PS3="Escolha uma das opções acima: "
select opt in 'Criar Chave' 'Abrir com Chave' 'Remover Chave' 'Checar Chave' Sair;
do
	case $opt in
		'Criar Chave')
			criarChaveHook
			break
			;;
		'Abrir com Chave')
			finalHook
			echo "Digite o caminho absoluto da chave: "
			read pathChave
			[[ -f $pathChave ]] || echo "Arquivo não foi encontrado"
			openCont
			cryptsetup luksOpen $diskFormat $openCont --key-file $pathChave
			openForm=/dev/mapper/$openCont
			mount $openForm /mnt/cst
			echo "Pronto! Está montado em /mnt/cst"

			break
			;;
		'Checar Chave')
			finalHook
			hookLuksDump
			;;
		'Remover Chave')
			finalHook
			openCont
			hookLuksDump
			echo "Digite qual chave você quer excluir: [01]"
			read excluirChave
			[[ -z $excluirChave ]] && excluirChave="01"
			echo "Deletando a chave..."
			echo "Logo em seguida será solicitado a senha do container"
			cryptsetup luksKillSlot $diskFormat -S $excluirChave

			break
			;;
		Sair)
			break
			;;
		*)
			echo "Opção inválida"
			break
			;;
	esac
done
fi #check sudo
