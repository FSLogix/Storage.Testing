######## 
#Session Server Configuration
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
$loginVSIfilename = "LVSITarget.zip"
$7zipFilename = "7z1805-x64.msi"
$fslogixAppsFilename = "FSLogixAppsSetup.exe"

#7Zip Executable location
$7zipExe = "C:\Program Files\7-Zip\7z.exe"

##Log File configuration
$logLoc = "C:\CustomPOSH_Logs"
$null = New-Item -ItemType Directory -Path $logLoc -Force

##Download Location
$downloadLoc = "C:\CustomPOSH_Downloads"

##Location for files to be downloaded
$downloadFiles = @()
$downloadFiles += ("https://publicfiledownloads.blob.core.windows.net/downloads/XenApp_and_XenDesktop_7_18.iso")
$downloadFiles += ("https://publicfiledownloads.blob.core.windows.net/downloads/LVSITarget.zip")
$downloadFiles += ("https://publicfiledownloads.blob.core.windows.net/downloads/7z1805-x64.msi")
$downloadFiles += ("https://publicfiledownloads.blob.core.windows.net/downloads/FSLogixAppsSetup.exe")

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

##Install 7Zip
if (Test-Path "$downloadLoc\$7zipFilename") {
    Start-Process -FilePath msiexec -ArgumentList "/i $downloadLoc\$7zipFilename","/quiet" -Wait
} else {
    "Could not find 7Zip File - Perhaps it failed to download, Please install manually" | Out-File -FilePath "$logLoc\Setup.log" -Append
}

##Install LoginVSI Target Software
if (Test-Path "$downloadLoc\$loginVSIfilename") {
    #Unzip the software install files
    Start-Process -FilePath $7zipExe -ArgumentList "x","$downloadLoc\$loginVSIfilename","-o$downloadLoc","-y" -Wait

    #Run the batch file
    Start-Process -FilePath cmd.exe -ArgumentList "/c $downloadLoc\VSITarget.cmd","1","1","1","1","1","'LoginVSI'" -Wait
} else {
    "Could not find LoginVSI Target Zip File - Perhaps it failed to download, Please install manually" | Out-File -FilePath "$logLoc\Setup.log" -Append
}

##Install XenDesktop
if (Test-Path "$downloadLoc\XenApp_and_XenDesktop_7_18.iso") {
    ##Mount the XenDesktop ISO
    $mountResult = Mount-DiskImage "$downloadLoc\XenApp_and_XenDesktop_7_18.iso" -PassThru
    
    #Get the volume from the mount operation
    $volumeObject = $mountResult | Get-Volume
    $driveLetter = $volumeObject.DriveLetter + ":"
} else {
    "Could not find XenDesktop ISO - Perhaps it failed to download, Please install manually" | Out-File -FilePath "$logLoc\VDASetup.log" -Append
}

#Run the XenDesktop Setup
if (Test-Path "$driveLetter\AutoSelect.exe") {
    ##Start the XenDesktop Setup
    #Start the installation with all the necessary parameters
    Start-Process -FilePath "$driveLetter\x64\Xendesktop Setup\XenDesktopVDASetup.exe" -ArgumentList "/QUIET","/NOREBOOT","/OPTIMIZE","/VERBOSELOG","/COMPONENTS VDA","/CONTROLLERS 'fsx-xdc-01.fslogix.local'","/ENABLE_HDX_PORTS","/ENABLE_REAL_TIME_TRANSPORT","/masterimage" -Wait

    #Dismount the ISO
    $mountResult | Dismount-DiskImage
} else {
    "Could not find XenDesktop Setup files - There must have been a problem extracting from the ISO" | Out-File -FilePath "$logLoc\VDASetup.log" -Append
}

#Run FSLogix Apps Setup
if (Test-Path "$downloadLoc\$fslogixAppsFilename") {
    ##Start FSLogix Apps Setup
    #Start the installation with all the necessary parameters
    Start-Process -FilePath "$downloadLoc\$fslogixAppsFilename" -ArgumentList "/install","/quiet","/norestart" -Wait

} else {
    "Could not find FSLogix Apps Setup files - There must have been a problem downloading the file, please install manually" | Out-File -FilePath "$logLoc\VDASetup.log" -Append
}
& shutdown -r -t 05