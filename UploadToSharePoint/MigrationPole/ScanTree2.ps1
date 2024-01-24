
Function Check-SPOFileExists()
{
    param
    (
        [Parameter(Mandatory=$true)] [string] $SiteURL,
        [Parameter(Mandatory=$true)] [string] $SourceFolderPath,
        [Parameter(Mandatory=$true)] [string] $LibraryName,
        [Parameter(Mandatory=$true)] [string] $LogFile
    )


}
Function Compare-Directory()
{
    param
    (
        [Parameter(Mandatory=$true)] [string] $SiteURL,
        [Parameter(Mandatory=$true)] [string] $SourceFolderPath,
        [Parameter(Mandatory=$true)] [string] $LibraryName,
        [Parameter(Mandatory=$true)] [string] $LogFile
    )
    $UserName = "admin-ld@ice-wm.com"
    $Password = "C3rt0dL0ICE$"

    $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    $Cred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $UserName, $SecurePassword
 

    $Source = Get-ChildItem -Path $SourceFolderPath -Recurse
    $SourceItems = $Source | Select-object FullName, PSIsContainer, LastWriteTime, @{Label='TargetItemURL';Expression={$_.FullName.Replace($SourceFolderPath,$TargetFolderSiteRelativeURL).Replace("\","/")}}
    Try {
        Add-content $Logfile -value "Number of Items Found in the Source: $($SourceItems.Count)"
 
       <#> #Connect to PnP Online
        Connect-PnPOnline -Url $SiteURL -Credentials $Cred #-Interactive 
 
        #Get the Target Folder to Upload
        $Web = Get-PnPWeb
        $List = Get-PnPList $LibraryName -Includes RootFolder
        $TargetFolder = $List.RootFolder
        $TargetFolderSiteRelativeURL = $TargetFolder.ServerRelativeURL.Replace($Web.ServerRelativeUrl,[string]::Empty)
        $TargetFolderSiteRelativeURL = $TargetFolderSiteRelativeURL + “/" + $SubFolder
        #>
        Write-Output $SourceItems


        $Counter = 1

        foreach ($item in $SourceItems)
        {
            $ItemFolderPath = Split-Path $Item.FullName -Parent
            $ItemName = Split-Path $Item.FullName -Leaf

            #Calculate Target Folder URL
            $TargetFolderURL = $ItemFolderPath.Replace("\","/")
            Write-Output "target:"+ $TargetFolderURL
            #Replace Invalid Characters
            $ItemName = [RegEx]::Replace($ItemName, "[{0}]" -f ([RegEx]::Escape([String]'\*:<>?/\|')), '_')

            If($item.PSIsContainer)
            {
                #Ensure Folder
                Write-host "Folder '$($ItemFolderPath)' $($Item.LastWriteTime)"
                Add-content $Logfile -value "Ensured Folder '$($ItemFolderPath)'"
            }
            Else
            {
                #Upload File
                #If($TargetFolderURL.StartsWith("/")) {$TargetFolderURL = $TargetFolderURL.Remove(0,1) }
                # $File  = Add-PnPFile -Path $_.FullName -Folder $TargetFolderURL
                Write-host "File '$($ItemName)' $($_.LastWriteTime) to Folder $ItemFolderPath"
                Add-content $Logfile -value " File '$($ItemName)' $($_.LastWriteTime) to Folder $ItemFolderPath"                       
            }
            $Counter++
        }

        <#
        $SourceItems | ForEach-Object 
        {
            #Calculate Target Folder URL
            $TargetFolderURL = (Split-Path $_.TargetItemURL -Parent).Replace("\","/")
            $ItemName = Split-Path $_.FullName -leaf
            Write-Output "target:"+ $TargetFolderURL
            #Replace Invalid Characters
            $ItemName = [RegEx]::Replace($ItemName, "[{0}]" -f ([RegEx]::Escape([String]'\*:<>?/\|')), '_')
            If($_.PSIsContainer)
            {
                #Ensure Folder
                $Folder  = Resolve-PnPFolder -SiteRelativePath ($TargetFolderURL+"/"+$ItemName)
                Write-host "Ensured Folder '$($ItemName)' to Folder $TargetFolderURL"
                Add-content $Logfile -value "Ensured Folder '$($ItemName)' to Folder $TargetFolderURL"
            }
            Else
            {
                #Upload File
                If($TargetFolderURL.StartsWith("/")) {$TargetFolderURL = $TargetFolderURL.Remove(0,1) }
                # $File  = Add-PnPFile -Path $_.FullName -Folder $TargetFolderURL
                Write-host "Uploaded File '$($_.FullName)' $($_.LastWriteTime) to Folder $TargetFolderURL"
                Add-content $Logfile -value "Uploaded File '$($_.FullName)' $($_.LastWriteTime) to Folder $TargetFolderURL"                       
            }
            $Counter++
        }
#>

    }
    catch {
        Write-host -f Red "Error:" $_.Exception.Message
        Add-content $Logfile -value "Error:$($_.Exception.Message)"
    }
    Finally {
        Add-content $Logfile -value "---------------------- Scan of the whole directory have been completed : $(Get-date -format 'dd/MM/yyy hh:mm:ss tt')-----------------"
     }
}
#Compare-Directory -SiteURL "https://icewm.sharepoint.com/sites/PleTst-POC" -SourceFolderPath "c:\ESD" -LogFile "c:\tmp\Compare_Tree_File.log" -LibraryName "Documents"
Compare-Directory -SiteURL "https://icewm.sharepoint.com/sites/ICEWaterEngineering1" -SourceFolderPath "\\SRV-FIC\PoleTest$" -LibraryName "Documents" -LogFile "c:\tmp\Compare_Tree_File.log"

