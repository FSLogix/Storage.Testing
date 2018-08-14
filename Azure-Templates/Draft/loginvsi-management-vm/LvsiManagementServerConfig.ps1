######## 
#File Server Configuration
#Copyright:         Free to use, please leave this header intact
#Author:            Leee Jeffries
#Company:           LJC (https://www.leeejeffries.com) 
#Script help:       Designed to be run from Azure ARM Template but can be run standalone
#Purpose:           Installs LoginVSI silently and configures the VSI_Share folder
#Usage:             Used for FSLogix storage testing
########

##Log File configuration
$logLoc = "C:\CustomPOSH_Logs"
$null = New-Item -ItemType Directory -Path $logLoc -Force

#Disable Windows Firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

##Create folder share for LoginVSI on the OS Drive
New-Item "C:\VSI_Share" –type directory
If (Test-Path "C:\VSI_Share") {
    New-SMBShare –Name "Storage" –Path "C:\VSI_Share" –ContinuouslyAvailable $true –FullAccess "fslogix.local\domain admins" -ChangeAccess "fslogix.local\authenticated users"
} else {
    "Failed to create LoginVSI Share, this will need to be done manually" | Out-File -FilePath "$logLoc\Setup.log" -Append 
}