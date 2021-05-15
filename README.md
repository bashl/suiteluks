# Scripts to manage luks containers

## Dependencies:
* cryptsetup, bc, fdisk, parted, lsblk

## Known limitations:
* Doesn't validate answers
* Hardcoded for ext4

## TODO:
* Validate answers
* Use PGP keys to decrypt and hide those gpg in files using steghide
* Clean code
* Reduce depedencies

---

# Scripts para gerenciar containers com luks

## Dependências:
* cryptsetup, bc, fdisk, parted, lsblk

## Limitações:
* Não tem validação de respostas
* Está hardcoded para containers em ext4

## TODO:
* Validação de respostas
* Desencriptar com chaves PGP escondidas em arquivos usando steghide
* Limpar o código
* Reduzir as dependências
