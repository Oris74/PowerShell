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
            $this.Web = Get-PnPWeb -Connection $this.connection
            $message = " connected with "+ $this.username + " to " + $this.sharePointFolderPath
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
        [string] $fileManaged,
        [String] $destinationFolder
    ) {
        #Upload File
        try {
            If($destinationFolder.StartsWith("/")) {$destinationFolder = $destinationFolder.Remove(0,1) }
            $fileStatus  = Add-PnPFile -Path $fileManaged -Folder $destinationFolder -Connection $this.connection
             #possible use-> $file itself isnt null if failed, but $file.UniqueId would be null if failed        

            if ($fileStatus.UniqueId ) { 
                $message = "The file $($fileManaged) has been added to SharePoint in folder $($destinationfolder)."
                $this.writeMessage($message, [colorText]::Green)
                return $True 
                }
                else { return $false  } 
            }
        catch {
            $message = "Error : *********  failed to upload file '$($fileManaged)' to Folder $($destinationFolder) **********"
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
                $this.Web = Get-PnPWeb -Connection $this.connection
                $List = Get-PnPList $LibraryName -Includes RootFolder -Connection $this.connection
                $targetFolder = $list.RootFolder
                $targetFolderSiteRelativeURL = $targetFolder.ServerRelativeURL.Replace($this.Web.ServerRelativeUrl,[string]::Empty)
                $targetFolderSiteRelativeURL = $targetFolderSiteRelativeURL + “/" + $SubFolder
                #Get All Items from the Source
                $sourceFiles = Get-ChildItem -Path $localFolderPath -Recurse
                $Files = $sourceFiles | Select-Object Name,FullName, PSIsContainer, LastWriteTime,  @{Label='TargetItemURL';Expression={$_.FullName.Replace($localFolderPath,$TargetFolderSiteRelativeURL).Replace("\","/")}}
                
                $message = "Number of Items Found in the Source: $($files.Count)"
                $this.writeMessage($message,[ColorText]::Green)

                #Upload Source Items from Fileshare to Target SharePoint Online document library
                $Counter = 1
                foreach ($selectedFile in $files) {
                        #Calculate Target Folder URL
                        $targetFolderURL = (Split-Path $selectedFile.TargetItemURL -Parent).Replace("\","/")
                        $fileName = Split-Path $selectedFile.FullName -leaf
                            
                        #Replace Invalid Characters
                        $fileName = [RegEx]::Replace($fileName, "[{0}]" -f ([RegEx]::Escape([String]'\*:<>?/\|')), '_')
         
                        #Display Progress bar
                        $status  = "uploading '" + $fileName + "' to " + $TargetFolderURL +" ($($Counter) of $($files.Count))"
                        Write-Progress -Activity "Uploading ..." -Status $Status -PercentComplete (($Counter / $files.Count) * 100)
          
                        If($selectedFile.PSIsContainer)        #check if the item is a folder 
                        {
                            #Ensure Folder
                            $folder  = Resolve-PnPFolder -SiteRelativePath ($TargetFolderURL + "/" +$fileName) -Connection $this.connection
                            $message = "Ensured Folder '$($fileName)' to Folder $TargetFolderURL"
                            $this.writeMessage( $message, [colorText]::Green)
                        }
                        Else
                        {
                            if ($this.AddFileToSharePoint($selectedFile.FullName ,$targetFolderSiteRelativeURL)) {
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
        [string] $SubFolder,
        [Bool]  $writeFile
    ) {
        [Int] $fileToUpload = 0

        # Get the list of files in the SharePoint folder
       
        $sourceFiles = Get-ChildItem -Path $localFolderPath -Recurse
        $files = $sourceFiles | Select-Object FullName, PSIsContainer, LastWriteTime,  @{Label='TargetItemURL';Expression={$_.FullName.Replace($localFolderPath,$TargetFolderSiteRelativeURL).Replace("\","/")}}
        
        $message = "Number of Items Found in the Source: $($files.Count)"
        $this.writeMessage($message,[ColorText]::Green)


        $this.Web = Get-PnPWeb -Connection $this.connection
        $List = Get-PnPList $libraryName -Includes RootFolder -Connection $this.connection
        $targetFolder = $list.RootFolder

        foreach ($selectedFile in $files) {
        # Go through each local file
        
         $targetFolderURL = $targetFolder.ServerRelativeURL.Replace($this.Web.ServerRelativeUrl,[string]::Empty)
         $targetFolderURL = $TargetFolderURL + "/" + $libraryName + "/"+ $SubFolder 
         $lengthTarget = $targetFolderURL.Length

         If($targetFolderURL.EndsWith("/")) {$targetFolderURL = $targetFolderURL.Remove($lengthTarget-1,1) }
         $fileName = Split-Path $selectedFile.FullName -leaf
         #Replace Invalid Characters
         $fileName = [RegEx]::Replace($fileName, "[{0}]" -f ([RegEx]::Escape([String]'\*:<>?/\|')), '_')
         $targetFileURL = ($targetFolderURL + $selectedFile.TargetItemURL).Replace("\","/")

         If($selectedFile.PSIsContainer)        #check if the item is a folder 
         { 
             #Ensure Folder
             $folder = Get-PnPFolder -Url $targetFileURL -ErrorAction SilentlyContinue -Connection $this.connection
                         
             if ($null -ne $folder) {
                $message = "Folder '$($fileName)' exist or have been created to " + $TargetFileURL
                $this.writeMessage( $message, [colorText]::Green)
             }else {
                $message = "Error Folder '$($fileName)' doesn't exist in " + $TargetFileURL
                $this.writeMessage( $message, [colorText]::Red)
                if ($writeFile) {
                    $result=Resolve-PnPFolder -SiteRelativePath $targetFileURL -Connection $this.connection
                    if ($result) {
                        $message = "Folder '$($fileName)' have been created "
                        $this.writeMessage( $message, [colorText]::Green)
                    }else {
                        $message = "Error Folder '$($fileName)' not created "
                        $this.writeMessage( $message, [colorText]::Red)
                    }
                }
             }
         }
         Else
         {
            $targetFolderURL = Split-Path $targetFileURL -Parent
            $sharePointFiles = Get-PnPFolderItem -FolderSiteRelativeUrl $targetFolderURL -ItemName $fileName  -Connection $this.connection
            # Search for the corresponding file on SharePoint
            $sharePointFile = $sharePointFiles | Where-Object { $_.Name -eq $fileName }
            
            if ($sharePointFile) {
                # Compare the modification dates of the files
                $sharePointFileTime = Get-PnPProperty -ClientObject $sharePointFile -Property TimeLastModified -Connection $this.connection
                if ($sharePointFileTime -eq $selectedFile.LastWriteTime) {
                    $message = "The file $($fileName) has the same modification date on SharePoint and locally."
                    $this.writeMessage($message, [colorText]::Black)
                } elseif($sharePointFileTime -cle $selectedFile.LastWriteTime) {
                    $message = "The file"+ $selectedFile.Name +" need to be updated on SharePoint ("+$sharePointFileTime+ ") and locally (" + $selectedFile.LastWriteTime +")."
                   $this.writeMessage($message, [colorText]::Red)

                   if ($writeFile) {
                        $this.AddFileToSharePoint($selectedFile.FullName,$targetFolderURL)
                        $this.updateLastWriteTime($selectedFile.FullName,$targetFolderURL+"\"+$fileName)
                    } else {
                        $message = " Write denied : Missing "+ $selectedFile.FullName +" it needs to be add to folder"+$targetFolderURL 
                        $this.writeMessage($message, [colorText]::Red)
                    }                 
                }
            } elseif ($writeFile) {
                    $this.AddFileToSharePoint($selectedFile.FullName,$targetFolderURL)
                    $this.updateLastWriteTime($selectedFile.FullName,$targetFolderURL+"\"+$fileName)
                } else {
                    $message = " Write denied : Missing "+ $selectedFile.FullName +" it needs to be add to folder"+$targetFolderURL 
                    $this.writeMessage($message, [colorText]::Red)
                }                 
          $fileToUpload++
         }
        }
        #$this.writeMessage("$fileToUpload Files need to be uploaded ",[ColorText]::Yellow) 
        Disconnect-PnPOnline
    }
    [void] updateLastWriteTime(
        [string] $localPathFile,
        [String] $URLPathFile
    ) {
         # Get the file as a list item and update the LastWriteTime property
         $siteFile = Get-PnPFile -Url ($URLPathFile) -AsListItem -connection $this.connection
         if($siteFile) {
            $siteFile["Modified"] = (Get-Item $localPathFile).LastWriteTime
            $siteFile.Update()
            Invoke-PnPQuery -Connection $this.connection 
        } else {
            $message = " File not found on " + $URLPathFile 
            $this.writeMessage($message, [colorText]::Red)
         }
         # Invoke the PnPQuery to save the changes
         

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

#$toto = [SharepointLibrary]::new('admin-ld@ice-wm.com', 'C3rt0dL0ICE$', 'https://icewm.sharepoint.com/sites/PleEtudes', "C:\Tmp\Migration-Etude.log" );
$toto = [SharepointLibrary]::new('admin-ld@ice-wm.com', 'C3rt0dL0ICE$', 'https://icewm.sharepoint.com/sites/PleTst-POC', "C:\Tmp\Migration-Etude.log" );
#$toto = [SharepointLibrary]::new('admin-ld@ice-wm.com', 'C3rt0dL0ICE$', 'https://icewm.sharepoint.com/sites/ICEWaterEngineering1', "C:\Tmp\Migration-LOG.log" );


$toto.openConnection()
#$toto.getFilesListFrom("DataExport")  
#$toto.uploadDirectory("C:\ESD","Documents","")
$toto.CompareFiles("C:\ESD","Documents","", $true)
#$toto.CompareFiles("\\SRV-FIC\PleEtudes$","Documents","Affaires", $false)
