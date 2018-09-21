######## 
#File Server Configuration
#Copyright:         Free to use, please leave this header intact
#Author:            Leee Jeffries
#Company:           LJC (https://www.leeejeffries.com) 
#Script help:       Designed to be run from Azure ARM Template but can be run standalone
#Purpose:           Installs LoginVSI silently and configures the VSI_Share folder
#Usage:             Used for FSLogix storage testing
########

function Disable-ieESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}

#Disabled IE Enhanced Security
Disable-ieESC

##Variable Configuration
#Download Filenames
$loginVSIfilename = "LoginVSI4132.exe"
$7zipFilename = "7z1805-x64.msi"

#7Zip Executable location
$7zipExe = "C:\Program Files\7-Zip\7z.exe"

#LoginVSI External Share Name
$loginVSIshareName = "\\fsx-lvsima-01.fslogix.local\VSI_Share"

#Log File configuration
$logLoc = "C:\CustomPOSH_Logs"

##Download Location
$downloadLoc = "C:\CustomPOSH_Downloads"

##Location for files to be downloaded
$downloadFiles = @()
$downloadFiles += ("https://publicfiledownloads.blob.core.windows.net/downloads/LoginVSI4132.exe")
$downloadFiles += ("https://publicfiledownloads.blob.core.windows.net/downloads/7z1805-x64.msi")
$downloadFiles += ("https://raw.githubusercontent.com/FSLogix/Storage.Testing/master/Azure-Templates/Downloads/LoginVSI_Workloads/FSLogix_KnowledgeWorker.txt")
$downloadFiles += ("https://raw.githubusercontent.com/FSLogix/Storage.Testing/master/Azure-Templates/Downloads/LoginVSI_Workloads/FSLogix_TaskWorker.txt")

Function Set-FolderACL {
    Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $folderPath,
         [Parameter(Mandatory=$true, Position=1)]
         [string] $userGroup
    )
    $userGroup
    $Acl = Get-Acl $folderPath
    $Ar = New-Object  system.security.accesscontrol.filesystemaccessrule("$userGroup","FullControl","Allow")
    $Acl.SetAccessRule($Ar)
    Set-Acl $folderPath $Acl
}

##Log Folder Creation
$null = New-Item -ItemType Directory -Path $logLoc -Force

##Download Folder Creation
$null = New-Item -ItemType Directory -Path $downloadLoc -Force

#Disable Windows Firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

##Create folder share for LoginVSI on the OS Drive
New-Item "C:\VSI_Share" –type directory
If (Test-Path "C:\VSI_Share") {
    New-SMBShare –Name "VSI_Share" –Path "C:\VSI_Share" –FullAccess "Everyone"
    Set-FolderACL -folderPath "C:\VSI_Share" -userGroup "Everyone"
} else {
    "Failed to create LoginVSI Share, this will need to be done manually" | Out-File -FilePath "$logLoc\Setup.log" -Append 
}

##Loop through the array and download all files
foreach ($file in $downloadFiles) {
    #Get filename of downloadable file
    $fileName = $file.SubString($file.LastIndexOf("/")+1,($file.Length - $file.LastIndexOf("/"))-1)    
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    Invoke-WebRequest -UseBasicParsing -Uri $file -OutFile "$downloadLoc\$fileName"
    
    #Wait for Windows to complete renaming the file from temp
    Start-Sleep -Second 5 
}

if (Test-Path "$downloadLoc\$7zipFilename") {
    Start-Process -FilePath msiexec -ArgumentList "/i $downloadLoc\$7zipFilename","/quiet" -Wait
} else {
    "Could not find 7Zip Instal File - Perhaps it failed to download, Please install manually" | Out-File -FilePath "$logLoc\Setup.log" -Append
}

if (Test-Path "$downloadLoc\$loginVSIfilename") {
    Start-Process -FilePath $7zipExe -ArgumentList "x","$downloadLoc\$loginVSIfilename","-o$downloadLoc","-y" -Wait
    Start-Process -FilePath "$downloadLoc\LoginVSI4132\1. Dataserver Setup\Setup.exe" -ArgumentList "-s $loginVSIshareName","-i","-qb" -Wait
} else {
    "Could not find LoginVSI Zip File - Perhaps it failed to download, Please install manually" | Out-File -FilePath "$logLoc\Setup.log" -Append
}

##Place custom workloads into the correct LVSI folder
New-Item -ItemType Directory -Path C:\VSI_Share\_VSI_Workloads -Name "Custom Workloads" -Force

if (Test-Path "$downloadLoc\FSLogix_KnowledgeWorker.txt") {
    Copy-Item -Path C:\CustomPOSH_Downloads\FSLogix_KnowledgeWorker.txt -Destination "C:\VSI_Share\_VSI_Workloads\Custom Workloads" -Force
} else {
    "Could not copy LVSI custom workloads (FSLogix_KnowledgeWorker.txt) - Perhaps it failed to download, Please install manually"
}

if (Test-Path "$downloadLoc\FSLogix_TaskWorker.txt") {
    Copy-Item -Path C:\CustomPOSH_Downloads\FSLogix_TaskWorker.txt -Destination "C:\VSI_Share\_VSI_Workloads\Custom Workloads" -Force
} else {
    "Could not copy LVSI custom workloads (FSLogix_TaskWorker.txt) - Perhaps it failed to download, Please install manually"
}