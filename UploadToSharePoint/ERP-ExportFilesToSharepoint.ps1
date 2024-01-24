$URL = "https://icewm.sharepoint.com/ICEWaterEngineering"

#First time tasks
#Install-Module SharePointPnPPowerShellOnline 
#$Creds = get-credential
#Add-PnPStoredCredential -Name $URL -Username $Creds.UserName -Password $Creds.Password

import-Module SharePointPnPPowerShellOnline 
Connect-PnPOnline $URL 

$Files = Get-ChildItem "\\SRV-12-20\DataExport$"
foreach($File in $Files){
    #$File = $Files[0]
    echo $File
    Add-PnPFile -Folder "Shared Documents" -Path $File.FullName
}
