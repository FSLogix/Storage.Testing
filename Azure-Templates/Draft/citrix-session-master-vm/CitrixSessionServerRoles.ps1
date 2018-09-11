######## 
#Session Server Configuration
#Copyright:         Free to use, please leave this header intact
#Author:            Leee Jeffries
#Company:           LJC (https://www.leeejeffries.com) 
#Script help:       Designed to be run from Azure ARM Template but can be run standalone
#Purpose:           Installs and Configures Citrix Virtual Apps and all roles automatically and silently
#Usage:             Used for FSLogix storage testing
########

##Variable Configuration
#Download Filenames
$dotNetFilename = "NDP471-KB4033342-x86-x64-AllOS-ENU.exe"

##Log File configuration
$logLoc = "C:\CustomPOSH_Logs"
$null = New-Item -ItemType Directory -Path $logLoc -Force

##Download Location
$downloadLoc = "C:\CustomPOSH_Downloads"

##Location for files to be downloaded
$downloadFiles = @()
$downloadFiles += ("https://web.leeejeffries.com/NDP471-KB4033342-x86-x64-AllOS-ENU.exe")

##Log Folder Creation
$null = New-Item -ItemType Directory -Path $logLoc -Force

##Download Folder Creation
$null = New-Item -ItemType Directory -Path $downloadLoc -Force

#Disable Windows Firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

##Loop through the array and download all files
foreach ($file in $downloadFiles) {
    #Get filename of downloadable file
    $fileName = $file.SubString($file.LastIndexOf("/")+1,($file.Length - $file.LastIndexOf("/"))-1)    
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    Invoke-WebRequest -UseBasicParsing -Uri $file -OutFile "$downloadLoc\$fileName"
    
    #Wait for Windows to complete renaming the file from temp
    Start-Sleep -Second 5 
}

##Install Remote Desktop Services
Install-WindowsFeature Remote-Desktop-Services,RDS-RD-Server,RDS-Licensing,RDS-Licensing-UI,RSAT-RDS-Licensing-Diagnosis-UI

##Install .Net Framework
if (Test-Path "$downloadLoc\$dotNetFilename") {
    Start-Process -FilePath $downloadLoc\$dotNetFilename -ArgumentList "/norestart","/quiet","/q:a" -Wait
} else {
    "Could not find DotNet File Download - Perhaps it failed to download, Please install manually" | Out-File -FilePath "$logLoc\Setup.log" -Append
}

& shutdown -r -t 05