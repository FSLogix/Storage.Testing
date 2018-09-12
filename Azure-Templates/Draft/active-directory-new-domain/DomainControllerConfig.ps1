######## 
#Domain Controller Configuration
#Copyright:         Free to use, please leave this header intact
#Author:            Leee Jeffries
#Company:           LJC (https://www.leeejeffries.com) 
#Script help:       Designed to be run from Azure ARM Template but can be run standalone
#Purpose:           Downloads and installed AD Connect silently and provisions an OU structure for the Domain Controller to support the testing environment
#Usage:             Used for FSLogix storage testing
########

##Log File configuration
$logLoc = "C:\CustomPOSH_Logs"
$null = New-Item -ItemType Directory -Path $logLoc -Force

##Download necessary files for Installation
#Local directory to download files
$downloadLoc = "$env:USERPROFILE\Downloads\Temp"
$null = New-Item -ItemType Directory -Path $downloadLoc -Force
 
##Location for files
$downloadFiles = @()
$downloadFiles += ("https://publicfiledownloads.blob.core.windows.net/downloads/AzureADConnect.msi")
 
##Loop through the array and download all files
foreach ($file in $downloadFiles) {
    #Get filename of downloadable file
    $fileName = $file.SubString($file.LastIndexOf("/")+1,($file.Length - $file.LastIndexOf("/"))-1)    
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    Invoke-WebRequest -UseBasicParsing -Uri $file -OutFile "$downloadLoc\$fileName"
    
    #Wait for Windows to complete renaming the file from temp
    Start-Sleep -Second 5

    if (Test-Path "$downloadLoc\$fileName") {
        Start-Process -FilePath msiexec.exe -ArgumentList "/i","$downloadLoc\$fileName","/q" -Wait
    } else {
        "Could not find Azure AD Connect Installer - Perhaps it failed to download, Please install manually" | Out-File -FilePath "$logLoc\Setup.log" -Append 
    }
}

#Run install for AD Connect
Start-Process -FilePath msiexec -ArgumentList "/i","$downloadloc\AzureADConnect.msi","/q" -Wait

#Create OU structure
#Citrix OU
New-ADOrganizationalUnit -Name "Citrix" -Path "DC=fslogix,DC=local"
New-ADOrganizationalUnit -Name "Infrastructure" -Path "OU=Citrix,DC=fslogix,DC=local"
New-ADOrganizationalUnit -Name "MasterVDA" -Path "OU=Citrix,DC=fslogix,DC=local"
New-ADOrganizationalUnit -Name "VDA" -Path "OU=Citrix,DC=fslogix,DC=local"
Set-GPInheritance -Target "OU=VDA,OU=Citrix,DC=fslogix,DC=local" -IsBlocked Yes
#LoginVSI
New-ADOrganizationalUnit -Name "LoginVSI" -Path "DC=fslogix,DC=local"
New-ADOrganizationalUnit -Name "Infrastructure" -Path "OU=LoginVSI,DC=fslogix,DC=local"
New-ADOrganizationalUnit -Name "Launchers" -Path "OU=LoginVSI,DC=fslogix,DC=local"
#General
New-ADOrganizationalUnit -Name "Servers" -Path "DC=fslogix,DC=local"

#Create Script Admin Account and add to Domain Admins
New-ADUser -Name Script.Admin -ChangePasswordAtLogon $false -Enabled $true -AccountPassword ("V3ryS3cur3Sc1ptAdm1n" | ConvertTo-SecureString -AsPlainText -Force)
Add-ADGroupMember -Identity "Domain Admins" -Members Script.Admin




