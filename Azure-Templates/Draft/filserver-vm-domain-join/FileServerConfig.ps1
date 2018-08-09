######## 
#File Server Configuration
#Copyright:         Free to use, please leave this header intact
#Author:            Leee Jeffries
#Company:           LJC (https://www.leeejeffries.com) 
#Script help:       Designed to be run from Azure ARM Template but can be run standalone
#Purpose:           Configures the datadisk of the VM and configures the Share and permissions
#Usage:             Used for FSLogix storage testing
########

##Log File configuration
$logLoc = "C:\CustomPOSH_Logs"
$null = New-Item -ItemType Directory -Path $logLoc -Force

##Create folder share for FSLogix
New-Item "D:\Shared" –type directory
New-SMBShare –Name "Storage" –Path "D:\Shared" –ContinuouslyAvailable –FullAccess "fslogix.local\domainadmins" -ChangeAccess "fslogix.local\authentication users"



