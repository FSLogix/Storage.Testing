######## 
#File Server Configuration
#Copyright:         Free to use, please leave this header intact
#Author:            Leee Jeffries
#Company:           LJC (https://www.leeejeffries.com) 
#Script help:       Designed to be run from Azure ARM Template but can be run standalone
#Purpose:           Configures the datadisk of the VM and configures the Share and permissions
#Usage:             Used for FSLogix storage testing
########

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
If (Test-Path "$driveLetter\Shared") {
    New-SMBShare –Name "Storage" –Path "$driveLetter\Shared" –FullAccess "lj.local\Domain Admins" -ChangeAccess "lj.local\Domain Users"
    Set-FolderACL -folderPath "$driveLetter\Shared" -userGroup "lj.local\Domain Users"
} else {
    "Failed to create File Share, this will need to be done manually" | Out-File -FilePath "$logLoc\Setup.log" -Append
}