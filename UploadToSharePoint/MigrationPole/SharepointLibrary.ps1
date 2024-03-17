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
    [string]    $logFile = "connection"
    [string]    $libraryName
    [Microsoft.SharePoint.Client.SecurableObject] $web
    [PnP.PowerShell.Commands.Base.PnPConnection] $connection
    [int] $totalFilesNbr = 0
    [int] $currentIndexFile = 1
    [bool]  $onlyNewFiles = 0
    [int]   $writtenFolder = 0
    [int]   $writtenFile = 0
    [int]   $updatedFile = 0
    [int]   $folderQty = 0
    [int]   $fileQty = 0
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

    [void] openConnection() {
        try {
            $this.credential = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $this.userName, $this.securePassword
            $this.connection = Connect-PnPOnline -Url $this.sharePointFolderPath -Credentials $this.credential -ReturnConnection #-Interactive 
            $this.Web = Get-PnPWeb -Connection $this.connection
            $message = " connected with "+ $this.username + " to " + $this.sharePointFolderPath
            $this.writeMessage($message, [colorText]::Green) 
        }
        catch {
            $message = "Error : failed to make connection !"
            $this.writeMessage($message, [colorText]::Red)

        }
    }

    [void] RAZInstance() {
        $this.writtenFolder = 0
        $this.writtenFile = 0
        $this.updatedFile = 0
        $this.folderQty = 0
        $this.fileQty = 0
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
                $message = "[ $($this.currentIndexFile) / $($this.totalFilesNbr) ] File $($fileManaged) has been added/Updated to SharePoint in folder $($destinationfolder)."
                $this.writeMessage($message, [colorText]::Green)
                return $True 
                }
                else { return $false  } 
            }
        catch {
            $message = "[ $($this.currentIndexFile) / $($this.totalFilesNbr) ] Error : *********  failed to upload file '$($fileManaged)' to Folder $($destinationFolder) **********"
            $this.writeMessage($message, [colorText]::Red)
            return $False
        }      
 
    }  
        # Method to compare files
    [void] CompareFiles(
            [string] $localFolderPath,
            [string] $libraryName,
            [string] $SubFolder,
            [bool]  $writeAccess = $true,
            [bool]  $onlyNewFiles = $False,
            [int]   $indexPositionStart = 0
    )
    {
        $this.RAZInstance() 
        $message += "`r`n ---------------------- start at : $(Get-date -format 'dd/MM/yyy hh:mm:ss tt')-----------------"
        $this.writeMessage($message, [colorText]::Green)

        # Get the list of files in the SharePoint folder
        $this.onlyNewFiles = $onlyNewFiles
        $this.logFile = ($SubFolder).Replace('\',"_").replace('/',"_")
        $sourceFiles = Get-ChildItem -Path ($localFolderPath + "\" + $subFolder) -Recurse
        $files = $sourceFiles | Select-Object FullName, PSIsContainer, LastWriteTime,  @{Label='TargetItemURL';Expression={$_.FullName.Replace($localFolderPath,$TargetFolderSiteRelativeURL).Replace("\","/")}}
        $this.totalFilesNbr = $files.Count
        $message = "Number of Items Found in the Source: $($this.totalFilesNbr)"
        $this.writeMessage($message,[ColorText]::Green)


        $this.Web = Get-PnPWeb -Connection $this.connection
        
        $List = Get-PnPList $libraryName -Includes RootFolder -Connection $this.connection
        
        $targetFolder = $list.RootFolder
        
        foreach ($selectedFile in $files) {
           
        # Go through each local file
            if ($this.currentIndexFile -lt $indexPositionStart ) {
                $this.writeMessage( "[ $($this.currentIndexFile) / $($this.totalFilesNbr) ] Skip $($selectedFile.FullName)", [colorText]::Black)
                $this.currentIndexFile++
                continue
            }
         $targetFolderURL = $targetFolder.ServerRelativeURL.Replace($this.Web.ServerRelativeUrl,[string]::Empty)
         #$targetFolderURL = $TargetFolderURL + "/" + $libraryName + "/"+ $SubFolder 
         #$targetFolderURL = $TargetFolderURL + "/"+ $SubFolder
         $lengthTarget = $targetFolderURL.Length

         If($targetFolderURL.EndsWith("/")) {$targetFolderURL = $targetFolderURL.Remove($lengthTarget-1,1) }
         $fileName = Split-Path $selectedFile.FullName -leaf
         #Replace Invalid Characters
         $fileName = [RegEx]::Replace($fileName, "[{0}]" -f ([RegEx]::Escape([String]'\*:<>?/\|')), '_')
         $targetFileURL = ($targetFolderURL + $selectedFile.TargetItemURL).Replace("\","/")

         If($selectedFile.PSIsContainer)        #check if the item is a folder 
         { 
            $this.folderQty += 1
             #Ensure Folder
             $folder = Get-PnPFolder -Url $targetFileURL -ErrorAction SilentlyContinue -Connection $this.connection
                         
             if ($null -ne $folder) {
                $message = "[ $($this.currentIndexFile) / $($this.totalFilesNbr) ] Folder '$($fileName)' exist on " + $TargetFileURL
                $this.writeMessage( $message, [colorText]::Black)
             }else {
                $message = "[ $($this.currentIndexFile) / $($this.totalFilesNbr) ] Error Folder '$($fileName)' doesn't exist in " + $TargetFileURL
                $this.writeMessage( $message, [colorText]::Red)
                if ($writeAccess) {
                    $result=Resolve-PnPFolder -SiteRelativePath $targetFileURL -Connection $this.connection
                    if ($result) {
                        $message = "[ $($this.currentIndexFile) / $($this.totalFilesNbr) ] Folder '$($fileName)' has been created "
                        $this.writeMessage( $message, [colorText]::Green)
                        $this.writtenFolder += 1
                    }else {
                        $message = "[ $($this.currentIndexFile) / $($this.totalFilesNbr) ] Error Folder '$($fileName)' not created "
                        $this.writeMessage( $message, [colorText]::Red)
                    }
                }
             }
         }
         Else
         {
            $this.fileQty += 1
            $targetFolderURL = Split-Path $targetFileURL -Parent
            #$sharePointFiles = Get-PnPListItem -List "Documents partages" -FolderServerRelativeUrl $list.ParentWebUrl+$targetFolderURL.Replace("\","/")  -Query "<View><Query><Where><Contains><FieldRef Name='FileLeafRef'/><Value Type='Text'>$($filename)</Value></Contains></Where></Query></View>" -Connection $this.connection
            $sharePointFiles = Get-PnPFolderItem -FolderSiteRelativeUrl $targetFolderURL -ItemName $fileName  -Connection $this.connection
            # Search for the corresponding file on SharePoint
            $sharePointFile = $sharePointFiles | Where-Object { $_.Name -eq $fileName }
            if ($sharePointfile.count -cgt 1 ) {
                $message = "[ $($this.currentIndexFile) / $($this.totalFilesNbr) ] ************** The file "+ $filename +" is in double : only the First is selected ***************"
                $this.writeMessage($message, [colorText]::Red)
                $sharePointFile = $sharePointFiles | Where-Object { $_.Name -eq $fileName } | Select-Object -First 1
            }
            if ($sharePointFile) {          # check if file exist in destination 
                # Compare the modification dates of the files
                $sharePointFileTime = Get-PnPProperty -ClientObject $sharePointFile -Property  TimeLastModified -Connection $this.connection
                if($sharePointFileTime -lt $selectedFile.LastWriteTime) {
                    $message = "[ $($this.currentIndexFile) / $($this.totalFilesNbr) ] File "+ $sharePointFile.Name +" exist and need to be updated on SharePoint ("+$sharePointFileTime+ ") and locally (" + $selectedFile.LastWriteTime +")."
                   $this.writeMessage($message, [colorText]::Red)

                   if ($writeAccess ) {
                        if( !$this.onlyNewFiles) {
                            $this.AddFileToSharePoint($selectedFile.FullName,$targetFolderURL)
                            $this.updateLastWriteTime($selectedFile.FullName,$targetFolderURL+"\"+$fileName)
                            $this.updatedFile += 1
                        } else {
                            $message = "[ $($this.currentIndexFile) / $($this.totalFilesNbr) ] New Files Only : "+ $selectedFile.FullName +" exist in folder "+$targetFolderURL +" but is not updated " 
                            $this.writeMessage($message, [colorText]::Black)
                        }
                    } else {
                        $message = "[ $($this.currentIndexFile) / $($this.totalFilesNbr) ] Update denied to file: "+ $selectedFile.FullName +" it needs to be add to folder"+$targetFolderURL 
                        $this.writeMessage($message, [colorText]::Red)
                    }                 
                } else {
                    $message = "[ $($this.currentIndexFile) / $($this.totalFilesNbr) ] The file "+ $selectedFile.FullName +" ("+$sharePointFileTime+ ") on sharepoint is more recent than  locally (" + $selectedFile.LastWriteTime +")"
                    $this.writeMessage($message, [colorText]::Black)
                }
            } elseif ($writeAccess) {           # file doesn't existe 
                    $this.AddFileToSharePoint($selectedFile.FullName,$targetFolderURL)
                    $this.updateLastWriteTime($selectedFile.FullName,$targetFolderURL+"\"+$fileName)
                    $this.writtenFile += 1
                } else {
                    $message = "[ $($this.currentIndexFile) / $($this.totalFilesNbr) ] Missing file - Add denied:  "+ $selectedFile.FullName +" needs to be add to folder"+$targetFolderURL 
                    $this.writeMessage($message, [colorText]::Red)
                }                 
          
         }
         $status  = "Processing '" + $selectedFile.Name + ":  ($($this.currentIndexFile) of $($files.Count))"
         Write-Progress -Activity "Uploading ..." -Status $Status -PercentComplete (($this.currentIndexFile / $files.Count) * 100)
         $this.currentIndexFile++
        }
        #$this.writeMessage("$this.currentIndexFile Files need to be uploaded ",[ColorText]::Yellow) 
        Invoke-PnPQuery -Connection $this.connection 
        $message = "`r`n`r`n Qty file processed : $($this.fileQty) `r`n Qty Folder processed :$($this.folderQty) `r`n New folders Added : $($this.writtenFolder) `r`n New files Added : $($this.writtenFile)  `r`n Updated files : $($this.updatedFile)" 
        $message += "`r`n ---------------------- Uploaded files Completed at : $(Get-date -format 'dd/MM/yyy hh:mm:ss tt')-----------------"
        $this.writeMessage($message, [colorText]::Green)

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
            
             
        } else {
            $message = "[ $($this.currentIndexFile) / $($this.totalFilesNbr) ] File not found on " + $URLPathFile 
            $this.writeMessage($message, [colorText]::Red)
         }
         # Invoke the PnPQuery to save the changes
         

       }

    [void] writeMessage(
        [string] $message,
        [ColorText] $colorText 
        ) {
            $filePath = $this.logFilePath + "\" + "Analyse_" + $this.logFile + ".log"
            Add-Content -Path $filePath -Value $message   
            Write-Host $message -ForegroundColor $colorText
      }
}

#$toto = [SharepointLibrary]::new('admin-ld@ice-wm.com', 'C3rt0dL0ICE$', 'https://icewm.sharepoint.com/sites/PleTst-POC', "C:\Tmp\Migration-test.log", $True );
$toto = [SharepointLibrary]::new('admin-ld@ice-wm.com', 'C3rt0dL0ICE$', 'https://icewm.sharepoint.com/sites/ServiceInformatique', "C:\Tmp");

#$toto = [SharepointLibrary]::new('admin-ld@ice-wm.com', 'C3rt0dL0ICE$', 'https://icewm.sharepoint.com/sites/PleEtudes', "C:\Tmp\Migration-Etude_DocTechnqiue.log",$true );

#$toto = [SharepointLibrary]::new 
# -username 'admin-ld@ice-wm.com'
# -myPswd 'C3rt0dL0ICE$'
# -sharePointFolderPath 'https://icewm.sharepoint.com/sites/Archives'
# -logFilePath "C:\Tmp";
 

#$toto = [SharepointLibrary]::new( "admin-ld@ice-wm.com", "C3rt0dL0ICE$", "https://icewm.sharepoint.com/sites/PleTst-POC", "C:\Tmp")
$toto = [SharepointLibrary]::new('admin-ld@ice-wm.com', 'C3rt0dL0ICE$', 'https://icewm.sharepoint.com/sites/PleProjetMER', "C:\Tmp" );
$toto.openConnection();
#$toto.getFilesListFrom("DataExport")  
#$toto.uploadDirectory("C:\ESD","Documents","")
#$toto.compareFiles("C:\ESD","Documents","", $true, $true, 0)
#$toto.CompareFiles("\\SRV-VEEAM\Sources_install$","Documents","Logiciels/Sources_install", $true, $true, 0)
#$toto.CompareFiles("\\SRV-FIC\PleEtudes$","Documents","DOC TECHNIQUE", $true, 0)
#$toto.CompareFiles
#    -localFolderPath "\\SRV-VEEAM\Archives Affaires$"
#    -libraryName "Documents"
#    -SubFolder "Affaires/Année 2011"
#    -writeAccess $true
#    -onlyNewFiles $true
#    -indexPositionStart 0;

    $toto.CompareFiles("\\SRV-FIC\PleProjetMER$", "Documents", "", $true, $true, 412417)


    #$toto.CompareFiles("\\SRV-VEEAM\Sources_info_icedom$","Documents","Affaires", $false)
