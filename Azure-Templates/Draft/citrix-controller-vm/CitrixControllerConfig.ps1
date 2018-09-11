######## 
#File Server Configuration
#Copyright:         Free to use, please leave this header intact
#Author:            Leee Jeffries
#Company:           LJC (https://www.leeejeffries.com) 
#Script help:       Designed to be run from Azure ARM Template but can be run standalone
#Purpose:           Configures the datadisk of the VM and configures the Share and permissions
#Usage:             Used for FSLogix storage testing
########

#Log File configuration
$logLoc = "C:\CustomPOSH_Logs"

##Download Location
$downloadLoc = "C:\CustomPOSH_Downloads"

##Location for files to be downloaded
$downloadFiles = @()
$downloadFiles += ("https://web.leeejeffries.com/XenApp_and_XenDesktop_7_18.iso")
$downloadFiles += ("https://download.microsoft.com/download/9/0/7/907AD35F-9F9C-43A5-9789-52470555DB90/ENU/SQLEXPR_x64_ENU.exe")

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

##Install XenDesktop
if (Test-Path "$downloadLoc\XenApp_and_XenDesktop_7_18.iso") {
    ##Mount the XenDesktop ISO
    $mountResult = Mount-DiskImage "$downloadLoc\XenApp_and_XenDesktop_7_18.iso" -PassThru
    
    #Get the volume from the mount operation
    $volumeObject = $mountResult | Get-Volume
    $driveLetter = $volumeObject.DriveLetter + ":"
} else {
    "Could not find XenDesktop ISO - Perhaps it failed to download, Please install manually" | Out-File -FilePath "$logLoc\Setup.log" -Append
}

#Run the XenDesktop Setup
if (Test-Path "$driveLetter\AutoSelect.exe") {
    ##Start the XenDesktop Setup
    #Start the installation with all the necessary parameters
    Start-Process -FilePath "$driveLetter\x64\XenDesktop Setup\XenDesktopServerSetup.exe" -ArgumentList "/components CONTROLLER,DESKTOPSTUDIO,DESKTOPDIRECTOR,LICENSESERVER,STOREFRONT","/configure_firewall","/disableexperiencemetrics","/quiet","/installdir 'C:\Program Files\Citrix'","/logpath $logLoc","/noreboot","/nosql","/tempdir 'c:\windows\temp'" -Wait

    #Dismount the ISO
    $mountResult | Dismount-DiskImage
} else {
    "Could not find XenDesktop Setup files - There must have been a problem extracting from the ISO" | Out-File -FilePath "$logLoc\Setup.log" -Append
}

##Install SQL Express
if (Test-Path "$downloadLoc\SQLEXPR_x64_ENU.exe") {
    #Extract SQL Server Setup
    Start-Process -FilePath "$downloadLoc\SQLEXPR_x64_ENU.exe" -ArgumentList "/q","/x:$downloadLoc\SQL" -Wait
    
    #Set parameters for SQL Server Express Installation
    #SQL Server Express does not like an Argument list in Powershell, it fails to parse the parameters and installation fails
    $params = @'
    /ACTION=Install /QS /FEATURES=SQL /INSTANCENAME=SQLEXPRESS /HIDECONSOLE /INDICATEPROGRESS="True" /IAcceptSQLServerLicenseTerms /SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE" /SQLSYSADMINACCOUNTS="builtin\administrators" /SKIPRULES="RebootRequiredCheck /TCPENABLED=1 /NPENABLED=1" 
'@ 
    #Install SQL Server
    Start-Process -FilePath "$downloadLoc\SQL\Setup.exe" $params -wait    

} else {
    "Could not find SQL Express Installation File - Perhaps it failed to download, Please install manually" | Out-File -FilePath "$logLoc\Setup.log" -Append   
}
& shutdown -r -t 05
