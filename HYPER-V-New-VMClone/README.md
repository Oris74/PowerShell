# New-VMClone

En s'appuyant sur les fonctionnalit�s d'export et d'importer d'Hyper-V, nous allons cloner une machine virtuelle existante.
Cette version n'int�gre pas de param�tres, il faut modifier les valeurs suivantes directement dans le script : $VMSourceName (VM source � cloner), $VMCloneName (nom du clone),
$VMCloneExportPath (dossier dans lequel stocker l'export), $VMCloneImportConfigPath (dossier dans lequel cr�er les fichiers de configuration de la VM import�e), $VMCloneImportVhdxPath (dossier dans lequel stocker les disques
virtuels de la VM import�e)

# Examples

Le script est pr�configur� pour cloner la VM "Windows-10" en "Windows-10-Clone".
L'export sera stock� � l'emplacement suivant et il sera supprim� � la fin de l'op�ration (cela n'alt�re pas la VM source) : "C:\TEMP"
L'import, c'est-�-dire le clone, aura des fichiers de configuration stock�s � cet emplacement : C:\ProgramData\Microsoft\Windows\Hyper-V\Virtual Machines\Windows-10-Clone
Les disques virtuels du clone seront quant � eux � cet emplacement : C:\ProgramData\Microsoft\Windows\Hyper-V\Virtual Machines\Windows-10-Clone\VHDX

# Links

[Cloner une VM avec Hyper-V](https://www.it-connect.fr/hyper-v-comment-cloner-une-vm/)