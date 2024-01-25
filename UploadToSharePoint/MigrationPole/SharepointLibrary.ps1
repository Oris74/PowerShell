enum ColorText {
    Black
    Red
    Yellow
    Green
}

class SharepointLibrary {
    [string]    $userName = $null
    [securestring]    $securePassword
    [pscredential]    $credential = $null
    [string]    $context = $Null
    [string]    $sharePointFolderPath =  $null
    [string]    $logfilePath = $null
    [string]    $libraryName
    [Microsoft.SharePoint.Client.SecurableObject] $web
    [PnP.PowerShell.Commands.Base.PnPConnection] $connection
    # Constructeur 
    SharepointLibrary(
        [string] $userName,
        [string] $myPswd,
        [String] $sharePointFolderPath,
        [string] $logFilePath
         ) {

        $this.username = $userName
        $this.sharePointFolderPath = $sharePointFolderPath
        $this.logfilePath = $logFilePath 
        $this.securePassword = ConvertTo-SecureString -String $myPswd -AsPlainText -Force
    }

    <######################################################################################>
    <###### Methode openConnection                                                   ######>
    <######                                                                          ######>
    <######################################################################################>

    [bool] openConnection() {
        try {
            $this.credential = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $this.userName, $this.securePassword
            $this.connection = Connect-PnPOnline -Url $this.sharePointFolderPath -Credentials $this.credential -ReturnConnection #-Interactive 
            $this.Web = Get-PnPWeb;
            $message = " connected with "+ $this.username + " to "+ $this.sharePointFolderPath
            $this.writeMessage($message, [colorText]::Green) 
            return $true
        }
        catch {
            $message = "Error : failed to make connection !"
            $this.writeMessage($message, [colorText]::Red)
           return $false
        }
    }

    [bool] getFilesListFrom([string] $subfolder) {
        #Get the Target Folder to Upload
        $this.Web = Get-PnPWeb
        $List = Get-PnPList $this.libraryName -Includes RootFolder;
        $TargetFolder = $List.RootFolder;
        $TargetFolderSiteRelativeURL = $TargetFolder.ServerRelativeURL.Replace($this.Web.ServerRelativeUrl,[string]::Empty);
        $TargetFolderSiteRelativeURL = $TargetFolderSiteRelativeURL + “/" + $SubFolder;
        return $true;
    }

    <######################################################################################>
    <###### Methode AddFileToSharePoint                                              ######>
    <###### Param: fileManaged                                                       ######>
    <######        destinationFolder                                                 ######>
    <######################################################################################>

    [bool] AddFileToSharePoint(
        [System.IO.FileInfo] $fileManaged,
        [String] $destinationfolder
    ) {
        #Upload File
        try {
            If($destinationfolder.StartsWith("/")) {$destinationfolder = $destinationfolder.Remove(0,1) }
                $File  = Add-PnPFile -Path $fileManaged.FullName -Folder $destinationfolder -Connection $this.connection
                 #possible use-> $file itself isnt null if failed, but $file.UniqueId would be null if failed

                if ($File.UniqueId ) { 
                    $message = "The file $($fileManaged.Name) has been added to SharePoint in folder $($destinationfolder)."
                    $this.writeMessage($message, [colorText]::Green)
                    return $True }
                else { return $false  } 
            }
        catch {
            $message = "Error : *********  failed to upload file '$($fileManaged.FullName)' to Folder $($destinationFolder) **********"
            writeMessage($message, [colorText]::Red)
            return $False
        }      
 
    }  

    [void] uploadDirectory(
        [string] $localFolderPath,
        [string] $libraryName,
        [string] $SubFolder
            ) {
            Try {
                $message = "---------------------- File Upload Script Started: $(Get-date -format 'dd/MM/yyy hh:mm:ss tt')-------------------"
                $this.writeMessage($message, [ColorText]::Black)
                 
                #Get the Target Folder to Upload
                $this.Web = Get-PnPWeb
                $List = Get-PnPList $LibraryName -Includes RootFolder
                $targetFolder = $list.RootFolder
                $targetFolderSiteRelativeURL = $targetFolder.ServerRelativeURL.Replace($this.Web.ServerRelativeUrl,[string]::Empty)
                $targetFolderSiteRelativeURL = $targetFolderSiteRelativeURL + “/" + $SubFolder
                #Get All Items from the Source
                $source = Get-ChildItem -Path $localFolderPath -Recurse
                $sourceItems = $Source | Select-Object FullName, PSIsContainer, LastWriteTime,  @{Label='TargetItemURL';Expression={$_.FullName.Replace($localFolderPath,$TargetFolderSiteRelativeURL).Replace("\","/")}}
                
                $message = "Number of Items Found in the Source: $($sourceItems.Count)"
                $this.writeMessage($message,[ColorText]::Green)

                #Upload Source Items from Fileshare to Target SharePoint Online document library
                $Counter = 1
                foreach ($selectedFile in $sourceItems) {5
                        #Calculate Target Folder URL
                        $targetFolderURL = (Split-Path $selectedFile.TargetItemURL -Parent).Replace("\","/")
                        $itemName = Split-Path $selectedFile.FullName -leaf
                            
                        #Replace Invalid Characters
                        $itemName = [RegEx]::Replace($ItemName, "[{0}]" -f ([RegEx]::Escape([String]'\*:<>?/\|')), '_')
         
                        #Display Progress bar
                        $status  = "uploading '" + $ItemName + "' to " + $TargetFolderURL +" ($($Counter) of $($SourceItems.Count))"
                        Write-Progress -Activity "Uploading ..." -Status $Status -PercentComplete (($Counter / $SourceItems.Count) * 100)
          
                        If($selectedFile.PSIsContainer)        #check if the item is a folder 
                        {
                            #Ensure Folder
                            $folder  = Resolve-PnPFolder -SiteRelativePath ($TargetFolderURL + "/" +$ItemName)
                            $message = "Ensured Folder '$($ItemName)' to Folder $TargetFolderURL"
                            $this.writeMessage( $message, [colorText]::Green)
                        }
                        Else
                        {
                            if ($this.uploadFile($selectedFile, $TargetFolderURL)) {
                                $message = "Uploaded File '$($selectedFile.FullName)' to Folder '$($TargetFolderURL.TargetItemURL)'"
                                $this.writeMessage($message, [colorText]::Green)
                            }                         
                        }
                        $Counter++
                }
               # return $true
            }
            Catch { 
                $message = "Error:" + $_.Exception.Message
                $this.writeMessage($message, [colorText]::Red) 
               # return $false
            }
            Finally {
                $message = "---------------------- File upload Script Completed: $(Get-date -format 'dd/MM/yyy hh:mm:ss tt')-----------------"
                $this.writeMessage($message, [colorText]::Green)
            }
        } 


        # Method to compare files
    [void] CompareFiles(
        [string] $localFolderPath,
        [string] $libraryName,
        [string] $SubFolder
    ) {
        [Int] $fileToUpload = 0

        # Get the list of files in the SharePoint folder
        $sharePointFiles = Get-PnPFolderItem -FolderSiteRelativeUrl $this.sharePointFolderPath -ItemType File -Connection $this.connection

        $this.Web = Get-PnPWeb
        $List = Get-PnPList $libraryName -Includes RootFolder
        $targetFolder = $list.RootFolder
        $targetFolderSiteRelativeURL = $targetFolder.ServerRelativeURL.Replace($this.Web.ServerRelativeUrl,[string]::Empty)
        $targetFolderSiteRelativeURL = $targetFolderSiteRelativeURL + “/" + $SubFolder


        # Go through each local file
        Get-ChildItem -Path $localFolderPath -File | ForEach-Object {
            $localFile = $_
            
            # Search for the corresponding file on SharePoint
            $sharePointFile = $sharePointFiles | Where-Object { $_.Name -eq $localFile.Name }
            
            if ($sharePointFile) {
                # Compare the modification dates of the files
                $sharePointFileTime = Get-PnPProperty -ClientObject $sharePointFile -Property TimeLastModified
                if ($sharePointFileTime -eq $localFile.LastWriteTime) {
                    $message = "The file $($localFile.Name) has the same modification date on SharePoint and locally."
                    writeMessage($message, [colorText]::Black)
                } else {
                    $message = "The file $($localFile.Name) has a different modification date on SharePoint and locally."
                    writeMessage($message, [colorText]::Yellow)
                }
            } else {
                $message = "The file $($localFile.Name) does not exist on SharePoint. Adding the file to SharePoint..."
                $this.writeMessage($message, [colorText]::Yellow)
                $fileToUpload++
                $this.AddFileToSharePoint($localFile,$targetFolderSiteRelativeURL)
            }
        }
        $this.writeMessage("$fileToUpload Files need to be uploaded ",[ColorText]::Yellow) 
        # Disconnect from SharePoint
        Disconnect-PnPOnline
    }

    [void] writeMessage(
        [string] $message,
        [ColorText] $colorText 
        ) {
            Add-Content -Path $this.logFilePath -Value $message   
            Write-Host $message -ForegroundColor $colorText
      }

      [bool] checkSPOFolderExists([string] $FolderRelativeURL) {
        
        Try {    
            #Setup the context
            $Ctx = New-Object Microsoft.SharePoint.Client.ClientContext($this.sharePointFolderPath)
            $Ctx.Credentials = $this.credential
 
            #Get the Web
            $this.Web = $Ctx.Web
            $Ctx.Load($this.Web)
            $Ctx.ExecuteQuery()
     
            #Check Folder Exists
            Try {
                $Folder = $this.Web.GetFolderByServerRelativeUrl($FolderRelativeURL)
                $Ctx.Load($Folder)
                $Ctx.ExecuteQuery()
     
                $message = "Folder Exists!"
                $this.writeMessage($message,[colorText]::Black)
                return $true
            }
            Catch {
                $message = "Folder Doesn't Exist!"+$_.Exception.Message
                $this.writeMessage($message, [colorText]::Yellow)
                return $false
            }       
        }
        Catch {
            $message = "Error: Checking Folder Exists!"+$_.Exception.Message
            $this.writeMessage($message, [colorText]::Red)
            return $false
        }
    }

}

$toto = [SharepointLibrary]::new('admin-ld@ice-wm.com', 'C3rt0dL0ICE$', 'https://icewm.sharepoint.com/sites/PleTst-POC', "C:\Tmp\Migration-LOG.log" );
#$toto = [SharepointLibrary]::new('admin-ld@ice-wm.com', 'C3rt0dL0ICE$', 'https://icewm.sharepoint.com/sites/ICEWaterEngineering1', "C:\Tmp\Migration-LOG.log" );


$toto.openConnection()
#$toto.getFilesListFrom("DataExport")  
#$toto.uploadDirectory("C:\ESD","Documents","DataExport")
$toto.CompareFiles("C:\ESD","Documents","DataExport")
