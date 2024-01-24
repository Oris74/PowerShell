#Load SharePoint CSOM Assemblies
#Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.dll"
#Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"
  
#Variables for Processing
$WebUrl = "https://icewm.sharepoint.com/sites/ICEWaterEngineering"
$LibraryName ="Documents"
$SourceFolder="C:\tmp"
$UserName = "ldebeaujon@ice-wm.com"

$Password ="Ic768969@"
  
#Setup Credentials to connect
$Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($UserName,(ConvertTo-SecureString $Password -AsPlainText -Force))
  
#Set up the context
$Context = New-Object Microsoft.SharePoint.Client.ClientContext($WebUrl)
$Context.Credentials = $Credentials
 
#Get the Library
$Library =  $Context.Web.Lists.GetByTitle($LibraryName)

foreach($File in (dir $SourceFolder -File))
{

   #Get the file from disk
   $FileStream = ([System.IO.FileInfo] (Get-Item $File.FullName)).OpenRead()

   #sharepoint online upload file powershell
    $FileCreationInfo = New-Object Microsoft.SharePoint.Client.FileCreationInformation
    $FileCreationInfo.Overwrite = $true
    $FileCreationInfo.ContentStream = $FileStream
    $FileCreationInfo.URL = $File
    $FileUploaded = $Library.RootFolder.Files.Add($FileCreationInfo)
  
   #powershell upload single file to sharepoint online
    $Context.Load($FileUploaded)
    $Context.ExecuteQuery()
  
 #Close file stream
 $FileStream.Close()
  
    write-host "Files $($File)have been uploaded!"
}

#Read more: https://www.sharepointdiary.com/2016/06/upload-files-to-sharepoint-online-using-powershell.html#ixzz8L2DLGwYr