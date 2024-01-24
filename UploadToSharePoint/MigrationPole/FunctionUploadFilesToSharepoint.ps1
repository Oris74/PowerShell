Function Migrate-PnPFolderToSPO()
{
    param
    (
        [Parameter(Mandatory=$true)] [string] $SiteURL,
        [Parameter(Mandatory=$true)] [string] $SourceFolderPath,
        [Parameter(Mandatory=$true)] [string] $LibraryName,
        [Parameter(Mandatory=$true)] [string] $SubFolder,
        [Parameter(Mandatory=$true)] [string] $LogFile
    )
    $UserName = "admin-ld@ice-wm.com"
    $Password = "C3rt0dL0ICE$"

    $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    $Cred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $UserName, $SecurePassword
 
#connect to sharepoint online site using powershell

#Read more: https://www.sharepointdiary.com/2018/03/connect-to-sharepoint-online-using-pnp-powershell.html#ixzz8LWOgQcBf
    Try {
        Add-content $Logfile -value "`n---------------------- File Upload Script Started: $(Get-date -format 'dd/MM/yyy hh:mm:ss tt')-------------------"
      
        #Connect to PnP Online
        Connect-PnPOnline -Url $SiteURL -Credentials $Cred #-Interactive 
 
        #Get the Target Folder to Upload
        $Web = Get-PnPWeb
        $List = Get-PnPList $LibraryName -Includes RootFolder
        $TargetFolder = $List.RootFolder
        $TargetFolderSiteRelativeURL = $TargetFolder.ServerRelativeURL.Replace($Web.ServerRelativeUrl,[string]::Empty)
        $TargetFolderSiteRelativeURL = $TargetFolderSiteRelativeURL + “/" + $SubFolder
        Write-Output $TargetFolderSiteRelativeURL

        #Get All Items from the Source
        $Source = Get-ChildItem -Path $SourceFolderPath -Recurse
        $SourceItems = $Source | Select-Object FullName, PSIsContainer, @{Label='TargetItemURL';Expression={$_.FullName.Replace($SourceFolderPath,$TargetFolderSiteRelativeURL).Replace("\","/")}}
        Add-content $Logfile -value "Number of Items Found in the Source: $($SourceItems.Count)"
  
        #Upload Source Items from Fileshare to Target SharePoint Online document library
        $Counter = 1
        $SourceItems | ForEach-Object {
                #Calculate Target Folder URL
                $TargetFolderURL = (Split-Path $_.TargetItemURL -Parent).Replace("\","/")
                $ItemName = Split-Path $_.FullName -leaf
                    
                #Replace Invalid Characters
                $ItemName = [RegEx]::Replace($ItemName, "[{0}]" -f ([RegEx]::Escape([String]'\*:<>?/\|')), '_')
 
                #Display Progress bar
                $Status  = "uploading '" + $ItemName + "' to " + $TargetFolderURL +" ($($Counter) of $($SourceItems.Count))"
                Write-Progress -Activity "Uploading ..." -Status $Status -PercentComplete (($Counter / $SourceItems.Count) * 100)
  
                If($_.PSIsContainer)
                {
                    #Ensure Folder
                    $folder  = Resolve-PnPFolder -SiteRelativePath ($TargetFolderURL+"/"+$ItemName)
                    Write-host "Ensured Folder '$($ItemName)' to Folder $TargetFolderURL"
                    Add-content $Logfile -value "Ensured Folder '$($ItemName)' to Folder $TargetFolderURL"
                }
                Else
                {
                        #Upload File
                        If($TargetFolderURL.StartsWith("/")) {$TargetFolderURL = $TargetFolderURL.Remove(0,1) }
                        $File  = Add-PnPFile -Path $_.FullName -Folder $TargetFolderURL
                        Write-host "Uploaded File '$($_.FullName)' to Folder $TargetFolderURL"
                        Add-content $Logfile -value "Uploaded File '$($_.FullName)' to Folder $TargetFolderURL"                       
                }
                $Counter++
        }
}
    Catch {
        Write-host -f Red "Error:" $_.Exception.Message
        Add-content $Logfile -value "Error:$($_.Exception.Message)"
    }
    Finally {
       Add-content $Logfile -value "---------------------- File upload Script Completed: $(Get-date -format 'dd/MM/yyy hh:mm:ss tt')-----------------"
    }
}
  
#Call the Function to Upload a Folder to SharePoint Online
Migrate-PnPFolderToSPO -SiteURL "https://icewm.sharepoint.com/sites/ICEWaterEngineering1" -SourceFolderPath "C:\ESD" -LibraryName "Documents" -SubFolder "DataExport" -LogFile "C:\Tmp\Migration-LOG.log"


#Read more: https://www.sharepointdiary.com/2019/03/sharepoint-online-migrate-folder-with-files-subfolders-using-powershell.html#ixzz8LVJ4cFyO