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

##Data disk initialisation - NOTE, setup for the number of disks I know will be attached - just a single data disk in this scenario
$newdisk = @(get-disk | Where-Object partitionstyle -eq 'raw')
$Labels = @('Data')

#Loop through any raw disks, create a filesystem and assign a driverletter
for($i = 0; $i -lt $newdisk.Count ; $i++)
{

    $disknum = $newdisk[$i].Number
    $dl = get-Disk $disknum | 
       Initialize-Disk -PartitionStyle GPT -PassThru | 
          New-Partition -AssignDriveLetter -UseMaximumSize
    Format-Volume -driveletter $dl.Driveletter -FileSystem NTFS -NewFileSystemLabel $Labels[$i] -Confirm:$false

}

##Create folder share for FSLogix in the Data drive
#Grab the driveletter from the created drive
$driveLetter = $dl.DriveLetter + ":"
New-Item "$driveLetter\Shared" –type directory
If (Test-Path "$driverLetter\Shared") {
    New-SMBShare –Name "Storage" –Path "D:\Shared" –ContinuouslyAvailable $true –FullAccess "fslogix.local\domain admins" -ChangeAccess "fslogix.local\authenticated users"
} else {
    "Failed to create File Share, this will need to be done manually" | Out-File -FilePath "$logLoc\Setup.log" -Append 
}