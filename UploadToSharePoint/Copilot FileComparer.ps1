# Importer le module Pester
Import-Module Pester
Import-Module PnP.PowerShell
class FileComparer {
    # Variables
     [string] $siteUrl 
     [string] $localFolderPath 
     [string] $sharePointFolderPath 
     [string] $logFilePath

  # Constructeur
  FileComparer([string] $siteUrl, [string] $localFolderPath, [string] $sharePointFolderPath, [string] $logFilePath) {
    $this.siteUrl = $siteUrl
    $this.localFolderPath = $localFolderPath
    $this.sharePointFolderPath = $sharePointFolderPath
    $this.logFilePath = $logFilePath
}


 # Method to add a file to SharePoint
 [void] AddFileToSharePoint([System.IO.FileInfo] $localFile) {
    # Add the file to SharePoint
    Add-PnPFile -Path $localFile.FullName -Folder $this.sharePointFolderPath
    $message = "The file $($localFile.Name) has been added to SharePoint."
    Write-Host $message
    Add-Content -Path $this.logFilePath -Value $message
}
 
# Method to compare files
    [void] CompareFiles() {
        
        # Connect to SharePoint
        Connect-PnPOnline -Url $this.siteUrl -Interactive

        # Get the list of files in the SharePoint folder
        $sharePointFiles = Get-PnPFolderItem -FolderSiteRelativeUrl $this.sharePointFolderPath -ItemType File

        # Go through each local file
        Get-ChildItem -Path $this.localFolderPath -File | ForEach-Object {
            $localFile = $_
            
            # Search for the corresponding file on SharePoint
            $sharePointFile = $sharePointFiles | Where-Object { $_.Name -eq $localFile.Name }
            
            if ($sharePointFile) {
                # Compare the modification dates of the files
                $sharePointFileTime = Get-PnPProperty -ClientObject $sharePointFile -Property TimeLastModified
                if ($sharePointFileTime -eq $localFile.LastWriteTime) {
                    $message = "The file $($localFile.Name) has the same modification date on SharePoint and locally."
                    Write-Host $message
                    Add-Content -Path $logFilePath -Value $message
                } else {
                    $message = "The file $($localFile.Name) has a different modification date on SharePoint and locally."
                    Write-Host $message
                    Add-Content -Path $logFilePath -Value $message
                }
            } else {
                $message = "The file $($localFile.Name) does not exist on SharePoint. Adding the file to SharePoint..."
                Write-Host $message
                Add-Content -Path $this.logFilePath -Value $message
                $this.AddFileToSharePoint($localFile)
            }
        }

        # Disconnect from SharePoint
        Disconnect-PnPOnline
    }

   
}

# Use the CompareFiles method of the FileComparer class
#[FileComparer]::CompareFiles()



# Définir les tests unitaires
<#Describe "FileComparer" {
    Context "CompareFiles method" {
        It "Compares files correctly" {
            # Ici, vous pouvez ajouter du code pour tester la méthode CompareFiles
            # Par exemple, vous pouvez créer des fichiers de test, exécuter la méthode CompareFiles, puis vérifier que les fichiers ont été correctement comparés
        }
    }

    Context "AddFileToSharePoint method" {
        It "Adds files correctly" {
            # Ici, vous pouvez ajouter du code pour tester la méthode AddFileToSharePoint
            # Par exemple, vous pouvez créer un fichier de test, exécuter la méthode AddFileToSharePoint, puis vérifier que le fichier a été correctement ajouté à SharePoint
        }
    }
}

# Exécuter les tests unitaires
#Invoke-Pester
#>
# Utiliser la méthode CompareFiles de la classe FileComparer
$ice=[FileComparer]::new("https://icewm.sharepoint.com/sites/PleTst-POC","C:\ESD","DataExport","C:\Tmp\Migration-LOG.log");
$ice.CompareFiles()