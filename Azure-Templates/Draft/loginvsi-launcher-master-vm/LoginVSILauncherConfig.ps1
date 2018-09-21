######## 
#File Server Configuration
#Copyright:         Free to use, please leave this header intact
#Author:            Leee Jeffries
#Company:           LJC (https://www.leeejeffries.com) 
#Script help:       Designed to be run from Azure ARM Template but can be run standalone
#Purpose:           Installs and Configures Citrix Virtual Apps and all roles automatically and silently
#Usage:             Used for FSLogix storage testing
########

##Function to disable IE enhanced security
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
$receiverFilename = "CitrixReceiver.exe"

##Log File configuration
$logLoc = "C:\CustomPOSH_Logs"

##Download Location
$downloadLoc = "C:\CustomPOSH_Downloads"

##Log Folder Creation
$null = New-Item -ItemType Directory -Path $logLoc -Force

##Download Folder Creation
$null = New-Item -ItemType Directory -Path $downloadLoc -Force

##Location for files to be downloaded
$downloadFiles = @()
$downloadFiles += ("https://publicfiledownloads.blob.core.windows.net/downloads/CitrixReceiver.exe")

##Loop through the array and download all files
foreach ($file in $downloadFiles) {
    #Get filename of downloadable file
    $fileName = $file.SubString($file.LastIndexOf("/")+1,($file.Length - $file.LastIndexOf("/"))-1)    
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    Invoke-WebRequest -UseBasicParsing -Uri $file -OutFile "$downloadLoc\$fileName"
    
    #Wait for Windows to complete renaming the file from temp
    Start-Sleep -Second 5 
}

#Disable Windows Firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

if (Test-Path "$downloadLoc\$receiverFilename") {
    Start-Process -FilePath "$downloadLoc\$receiverFilename" -ArgumentList "/silent" -Wait
} else {
    "Could not find Citrix Receiver Install File - Perhaps it failed to download, Please install manually" | Out-File -FilePath "$logLoc\Setup.log" -Append
}