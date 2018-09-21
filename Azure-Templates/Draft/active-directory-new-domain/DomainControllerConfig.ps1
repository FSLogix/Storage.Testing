######## 
#Domain Controller Configuration
#Copyright:         Free to use, please leave this header intact
#Author:            Leee Jeffries
#Company:           LJC (https://www.leeejeffries.com) 
#Script help:       Designed to be run from Azure ARM Template but can be run standalone
#Purpose:           Downloads and installed AD Connect silently and provisions an OU structure for the Domain Controller to support the testing environment
#Usage:             Used for FSLogix storage testing
########

#Download Filenames
$7zipFilename = "7z1805-x64.msi"
$gpoFilename = "GPO_To_Import.zip"
$adConnectFilename = "AzureADConnect.msi"

#7Zip Executable location
$7zipExe = "C:\Program Files\7-Zip\7z.exe"

##Log File configuration
$logLoc = "C:\CustomPOSH_Logs"
$null = New-Item -ItemType Directory -Path $logLoc -Force

##Download necessary files for Installation
#Local directory to download files
$downloadLoc = "C:\CustomPOSH_Downloads"
$null = New-Item -ItemType Directory -Path $downloadLoc -Force
 
##Location for files
$downloadFiles = @()
$downloadFiles += ("https://publicfiledownloads.blob.core.windows.net/downloads/AzureADConnect.msi")
$downloadFiles += ("https://publicfiledownloads.blob.core.windows.net/downloads/GPO_To_Import.zip")
$downloadFiles += ("https://publicfiledownloads.blob.core.windows.net/downloads/7z1805-x64.msi")
 
##Loop through the array and download all files
foreach ($file in $downloadFiles) {
    #Get filename of downloadable file
    $fileName = $file.SubString($file.LastIndexOf("/")+1,($file.Length - $file.LastIndexOf("/"))-1)    
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    Invoke-WebRequest -UseBasicParsing -Uri $file -OutFile "$downloadLoc\$fileName"
    
    #Wait for Windows to complete renaming the file from temp
    Start-Sleep -Second 5    
}

if (Test-Path "$downloadLoc\$adConnectFilename") {
    Start-Process -FilePath msiexec.exe -ArgumentList "/i","$downloadLoc\$fileName","/q" -Wait
} else {
    "Could not find Azure AD Connect Installer - Perhaps it failed to download, Please install manually" | Out-File -FilePath "$logLoc\Setup.log" -Append 
}

if (Test-Path "$downloadLoc\$7zipFilename") {
    Start-Process -FilePath msiexec -ArgumentList "/i $downloadLoc\$7zipFilename","/quiet" -Wait
} else {
    "Could not find 7Zip Instal File - Perhaps it failed to download, Please install manually" | Out-File -FilePath "$logLoc\Setup.log" -Append
}

if (Test-Path "$downloadLoc\$gpoFilename") {
    Start-Process -FilePath $7zipExe -ArgumentList "x","$downloadLoc\$gpoFilename","-o$downloadLoc","-y" -Wait
} else {
    "Could not find GPO Zip File - Perhaps it failed to download, Please install GPOs Manually" | Out-File -FilePath "$logLoc\Setup.log" -Append
}

#Run install for AD Connect
Start-Process -FilePath msiexec -ArgumentList "/i","$downloadloc\AzureADConnect.msi","/q" -Wait

#Create OU structure
#Citrix OU
New-ADOrganizationalUnit -Name "Citrix" -Path "DC=fslogix,DC=local"
New-ADOrganizationalUnit -Name "Infrastructure" -Path "OU=Citrix,DC=fslogix,DC=local"
New-ADOrganizationalUnit -Name "MasterVDA" -Path "OU=Citrix,DC=fslogix,DC=local"

#General
New-ADOrganizationalUnit -Name "Servers" -Path "DC=fslogix,DC=local"

#Create Script Admin Account and add to Domain Admins
New-ADUser -Name Script.Admin -ChangePasswordAtLogon $false -Enabled $true -AccountPassword ("V3ryS3cur3Sc1ptAdm1n" | ConvertTo-SecureString -AsPlainText -Force)
Add-ADGroupMember -Identity "Domain Admins" -Members Script.Admin

#LoginVSI Configuration
##################################################
# Login VSI Active Directory setup script
# v1.1
##################################################
$baseOU = "DC=fslogix,DC=local"
$numUsers = "50"
$userName = "LoginVSI"
$passWord = "Password!"
$userDomain = "fslogix.local"
$VSIshare = "\\fsx-lvsima-01.fslogix.local\VSI_Share"
$FormatLength = "1"
$LauncherAccount = "Launcher-v4"
$LauncherPassword = "Password!"
$ConfirmPreference="none"

Import-Module ActiveDirectory
New-ADOrganizationalUnit -ProtectedFromAccidentalDeletion $false -name "LoginVSI" -path "$baseOU"
New-ADOrganizationalUnit -ProtectedFromAccidentalDeletion $false -name "Computers" -path "OU=LoginVSI,$baseOU"
New-ADOrganizationalUnit -ProtectedFromAccidentalDeletion $false -name "Launcher" -path "OU=Computers,OU=LoginVSI,$baseOU"
New-ADOrganizationalUnit -ProtectedFromAccidentalDeletion $false -name "Target" -path "OU=Computers,OU=LoginVSI,$baseOU"
New-ADOrganizationalUnit -ProtectedFromAccidentalDeletion $false -name "Users" -path "OU=LoginVSI,$baseOU"
New-ADOrganizationalUnit -ProtectedFromAccidentalDeletion $false -name "Launcher" -path "OU=Users,OU=LoginVSI,$baseOU"
New-ADOrganizationalUnit -ProtectedFromAccidentalDeletion $false -name "Target" -path "OU=Users,OU=LoginVSI,$baseOU"

##Import GPO Objects
import-gpo -BackupGpoName "XenDesktop Server 2016 - FSLogix Settings" -TargetName "XenDesktop Server 2016 - FSLogix Settings" -path "$downloadLoc\GPO_To_Import" -CreateIfNeeded | new-gplink -target "OU=Target,OU=Computers,OU=LoginVSI,DC=fslogix,DC=local"
import-gpo -BackupGpoName "XenDesktop Server 2016 - FSLogix Network OST Redirection" -TargetName "XenDesktop Server 2016 - FSLogix Network OST Redirection" -path "$downloadLoc\GPO_To_Import" -CreateIfNeeded | new-gplink -target "OU=Target,OU=Computers,OU=LoginVSI,DC=fslogix,DC=local"
import-gpo -BackupGpoName "XenDesktop Server 2016 - FSLogix Enable Search Service" -TargetName "XenDesktop Server 2016 - FSLogix Enable Search Service" -path "$downloadLoc\GPO_To_Import" -CreateIfNeeded | new-gplink -target "OU=Target,OU=Computers,OU=LoginVSI,DC=fslogix,DC=local"
import-gpo -BackupGpoName "Trusted Sites" -TargetName "Trusted Sites" -path "$downloadLoc\GPO_To_Import" -CreateIfNeeded | new-gplink -target "DC=fslogix,DC=local"





