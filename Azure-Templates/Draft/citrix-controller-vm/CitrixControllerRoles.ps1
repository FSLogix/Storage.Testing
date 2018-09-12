######## 
#Citrix Controller Roles Installation
#Copyright:         Free to use, please leave this header intact
#Author:            Leee Jeffries
#Company:           LJC (https://www.leeejeffries.com) 
#Original Credit and References: Dennis Span (http://dennisspan.com)
#Script help:       Designed to be run from Azure ARM Template but can be run standalone
#Purpose:           Configures the datadisk of the VM and configures the Share and permissions
#Usage:             Used for FSLogix storage testing
########

# Get the script parameters if there are any
param
(
    # The only parameter which is really required is 'Uninstall'
    # If no parameters are present or if the parameter is not
    # 'uninstall', an installation process is triggered
    [string]$Installationtype
)

# define Error handling
# note: do not change these values
$global:ErrorActionPreference = "Stop"
if($verbose){ $global:VerbosePreference = "Continue" }

# FUNCTION DS_WriteLog
#==========================================================================
Function DS_WriteLog {
    <#
        .SYNOPSIS
        Write text to this script's log file
        .DESCRIPTION
        Write text to this script's log file
        .PARAMETER InformationType
        This parameter contains the information type prefix. Possible prefixes and information types are:
            I = Information
            S = Success
            W = Warning
            E = Error
            - = No status
        .PARAMETER Text
        This parameter contains the text (the line) you want to write to the log file. If text in the parameter is omitted, an empty line is written.
        .PARAMETER LogFile
        This parameter contains the full path, the file name and file extension to the log file (e.g. C:\Logs\MyApps\MylogFile.log)
        .EXAMPLE
        DS_WriteLog -InformationType "I" -Text "Copy files to C:\Temp" -LogFile "C:\Logs\MylogFile.log"
        Writes a line containing information to the log file
        .Example
        DS_WriteLog -InformationType "E" -Text "An error occurred trying to copy files to C:\Temp (error: $($Error[0]))" -LogFile "C:\Logs\MylogFile.log"
        Writes a line containing error information to the log file
        .Example
        DS_WriteLog -InformationType "-" -Text "" -LogFile "C:\Logs\MylogFile.log"
        Writes an empty line to the log file
    #>
    [CmdletBinding()]
	Param( 
        [Parameter(Mandatory=$true, Position = 0)][String]$InformationType,
        [Parameter(Mandatory=$true, Position = 1)][AllowEmptyString()][String]$Text,
        [Parameter(Mandatory=$true, Position = 2)][AllowEmptyString()][String]$LogFile
    )

	$DateTime = (Get-Date -format dd-MM-yyyy) + " " + (Get-Date -format HH:mm:ss)
	
    if ( $Text -eq "" ) {
        Add-Content $LogFile -value ("") # Write an empty line
    } Else {
	    Add-Content $LogFile -value ($DateTime + " " + $InformationType + " - " + $Text)
    }
}
#==========================================================================

##AutoLogon Function to facilitate multiple script launches in succession
Function Set-AutoLogon{

    [CmdletBinding()]
    Param(        
        [Parameter(Mandatory=$True,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [String[]]$DefaultUsername,
        [Parameter(Mandatory=$True,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [String[]]$DefaultPassword,
        [Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [AllowEmptyString()]
        [String[]]$AutoLogonCount,
        [Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [AllowEmptyString()]
        [String[]]$Script                
    )

    Begin
    {
        #Registry path declaration
        $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        $RegROPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"    
    }
    
    Process
    {
        try
        {
            #setting registry values
            Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -type String  
            Set-ItemProperty $RegPath "DefaultUsername" -Value "$DefaultUsername" -type String  
            Set-ItemProperty $RegPath "DefaultPassword" -Value "$DefaultPassword" -type String
            if($AutoLogonCount)
            {                
                Set-ItemProperty $RegPath "AutoLogonCount" -Value "$AutoLogonCount" -type DWord            
            }
            else
            {
                Set-ItemProperty $RegPath "AutoLogonCount" -Value "1" -type DWord
            }
            if($Script)
            {                
                Set-ItemProperty $RegROPath "(Default)" -Value "$Script" -type String            
            }
            else
            {            
                Set-ItemProperty $RegROPath "(Default)" -Value "" -type String            
            }        
        }
        catch
        {
            Write-Output "An error had occured $Error"            
        }
    }    
    End
    {        
        #End
    }
}

##Function to grab current script directory
function Get-Script-Directory
{
    $scriptInvocation = (Get-Variable MyInvocation -Scope 1).Value
    return Split-Path $scriptInvocation.MyCommand.Path
}

$currentFolder = Get-Script-Directory

################
# Main section #
################

#Script Run Credentials
$secUser = "fslogix.local\Script.Admin"
$secPasswd = "V3ryS3cur3Sc1ptAdm1n"

# Disable File Security
$env:SEE_MASK_NOZONECHECKS = 1

# Custom variables [edit]
$BaseLogDir = "C:\CustomPOSH_Logs"                              # [edit] add the location of your log directory here
$PackageName = "Citrix Delivery Controller Roles"      # [edit] enter the display name of the software (e.g. 'Arcobat Reader' or 'Microsoft Office')

# Global variables
$StartDir = $PSScriptRoot # the directory path of the script currently being executed
if (!($Installationtype -eq "Uninstall")) { $Installationtype = "Install" }
$LogDir = (Join-Path $BaseLogDir $PackageName).Replace(" ","_")
$LogFileName = "$($Installationtype)_$($PackageName).log"
$LogFile = Join-path $LogDir $LogFileName

# Create the log directory if it does not exist
if (!(Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType directory | Out-Null }

# Create new log file (overwrite existing one)
New-Item $LogFile -ItemType "file" -force | Out-Null

DS_WriteLog "I" "START SCRIPT - $Installationtype $PackageName" $LogFile
DS_WriteLog "-" "" $LogFile


#################################################
# INSTALL MICROSOFT ROLES AND FEATURES          #
#################################################

DS_WriteLog "I" "Add Windows roles and features:" $LogFile
DS_WriteLog "I" "-.Net Framework 3.5 (W2K8R2 only)" $LogFile
DS_WriteLog "I" "-.Net Framework 4.6 (W2K12 + W2K16)" $LogFile
DS_WriteLog "I" "-Desktop experience (W2K8R2 + W2K12)" $LogFile
DS_WriteLog "I" "-Group Policy Management Console" $LogFile
DS_WriteLog "I" "-Remote Server Administration Tools (AD DS Snap-Ins)" $LogFile
DS_WriteLog "I" "-Remote Desktop Licensing Tools" $LogFile
DS_WriteLog "I" "-Telnet Client" $LogFile
DS_WriteLog "I" "-Windows Process Activation Service" $LogFile

DS_WriteLog "-" "" $LogFile

DS_WriteLog "I" "Retrieve the OS version and name" $LogFile

# Check the windows version
# URL: https://en.wikipedia.org/wiki/List_of_Microsoft_Windows_versions
# -Windows Server 2016    -> NT 10.0
# -Windows Server 2012 R2 -> NT 6.3
# -Windows Server 2012    -> NT 6.2
[string]$WindowsVersion = ( Get-WmiObject -class Win32_OperatingSystem ).Version
switch -wildcard ($WindowsVersion)
    { 
        "*10*" { 
                $OSVER = "W2K16"
                $OSName = "Windows Server 2016"
                $LogFile2 = Join-Path $LogDir "Install_RolesAndFeatures.log"

                DS_WriteLog "I" "The current operating system is $($OSNAME) ($($OSVER))" $LogFile
                DS_WriteLog "-" "" $LogFile
                DS_WriteLog "I" "Roles and Features installation log file: $LogFile2" $LogFile
                DS_WriteLog "I" "Start the installation ..." $LogFile

                # Install Windows Features
                try {
                    Install-WindowsFeature NET-Framework-45-Core,GPMC,RSAT-ADDS-Tools,RDS-Licensing-UI,WAS,Telnet-Client -logpath $LogFile2
                    Install-WindowsFeature Web-Server -logpath $LogFile2 
                    DS_WriteLog "S" "The windows features were installed successfully!" $LogFile 
                } catch {
                    DS_WriteLog "E" "An error occurred while installing the windows features (error: $($error[0]))" $LogFile
                    Exit 1
                }
            } 
        "*6.3*" { 
                $OSVER = "W2K12R2"
                $OSName = "Windows Server 2012 R2"
                $LogFile2 = Join-Path $LogDir "Install_RolesAndFeatures.log"

                DS_WriteLog "I" "The current operating system is $($OSNAME) ($($OSVER))" $LogFile
                DS_WriteLog "-" "" $LogFile
                DS_WriteLog "I" "Roles and Features installation log file: $LogFile2" $LogFile
                DS_WriteLog "I" "Start the installation ..." $LogFile

                # Install Windows Features
                try {
                    Install-WindowsFeature NET-Framework-45-Core,Desktop-Experience,GPMC,RSAT-ADDS-Tools,RDS-Licensing-UI,WAS,Telnet-Client -logpath $LogFile2
                    Install-WindowsFeature Web-Server -logpath $LogFile2 
                    DS_WriteLog "S" "The windows features were installed successfully!" $LogFile
                } catch {
                    DS_WriteLog "E" "An error occurred while installing the windows features (error: $($error[0]))" $LogFile
                    Exit 1
                }
            } 
        "*6.2*" { 
                $OSVER = "W2K12"
                $OSName = "Windows Server 2012"
                $LogFile2 = Join-Path $LogDir "Install_RolesAndFeatures.log"
                
                DS_WriteLog "I" "The current operating system is $($OSNAME) ($($OSVER))" $LogFile
                DS_WriteLog "-" "" $LogFile
                DS_WriteLog "I" "Roles and Features installation log file: $LogFile2" $LogFile
                DS_WriteLog "I" "Start the installation ..." $LogFile

                # Install Windows Features
                try {
                    Install-WindowsFeature NET-Framework-45-Core,Desktop-Experience,GPMC,RSAT-ADDS-Tools,RDS-Licensing-UI,WAS,Telnet-Client -logpath $LogFile2
                    Install-WindowsFeature Web-Server -logpath $LogFile2                                     
                    DS_WriteLog "S" "The windows features were installed successfully!" $LogFile
                } catch {
                    DS_WriteLog "E" "An error occurred while installing the windows features (error: $($error[0]))" $LogFile
                    Exit 1
                }
            }        
        default { 
            $OSName = ( Get-WmiObject -class Win32_OperatingSystem ).Caption
            DS_WriteLog "E" "The current operating system $($OSName) is unsupported" $LogFile
            DS_WriteLog "I" "This script will now be terminated" $LogFile
            DS_WriteLog "-" "" $LogFile
            Exit 1
            }
    }

##Download and install .Net 4.7.1
$downloadLoc = "C:\CustomPOSH_Downloads"
DS_WriteLog "I" "Download location is $downloadLoc" $LogFile

##Location for files to be downloaded
$downloadFiles = @()
$downloadFiles += ("https://download.microsoft.com/download/9/E/6/9E63300C-0941-4B45-A0EC-0008F96DD480/NDP471-KB4033342-x86-x64-AllOS-ENU.exe")
DS_WriteLog "I" "Download .NET 4.7.1 Install" $LogFile

##Download Folder Creation
$null = New-Item -ItemType Directory -Path $downloadLoc -Force

##Loop through the array and download all files
foreach ($file in $downloadFiles) {
    #Get filename of downloadable file
    $fileName = $file.SubString($file.LastIndexOf("/")+1,($file.Length - $file.LastIndexOf("/"))-1)    
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    Invoke-WebRequest -UseBasicParsing -Uri $file -OutFile "$downloadLoc\$fileName"
    
    #Wait for Windows to complete renaming the file from temp
    Start-Sleep -Second 5 
}

if (Test-Path "$downloadLoc\$fileName") {
    ##Trigger .Net 4.7 Installation
    Start-Process -FilePath "$downloadLoc\$fileName" -ArgumentList "/q", "/norestart" -Wait
    DS_WriteLog "I" ".Net 4.7 Installation completed" $LogFile
} else {
    DS_WriteLog "E" "Could not find .Net Installer - Perhaps it failed to download, Please install manually" $LogFile
}

# Enable File Security  
Remove-Item env:\SEE_MASK_NOZONECHECKS

DS_WriteLog "-" "" $LogFile
DS_WriteLog "I" "End of script" $LogFile

#Set AutoLogon
Set-AutoLogon -DefaultUsername $secUser -DefaultPassword $secPasswd -Script "C:\Windows\System32\WindowsPowershell\V1.0\powershell.exe -ExecutionPolicy Unrestricted -File ""$currentFolder\CitrixControllerConfig.ps1""" -AutoLogonCount 1

#Reboot after role installation
& Shutdown -r -t 05