######## 
#Session Server Configuration
#Copyright:         Free to use, please leave this header intact
#Author:            Leee Jeffries
#Company:           LJC (https://www.leeejeffries.com) 
#Script help:       Designed to be run from Azure ARM Template but can be run standalone
#Purpose:           Installs and Configures Citrix Virtual Apps and all roles automatically and silently
#Usage:             Used for FSLogix storage testing
########

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

##Variable Configuration
#Download Filenames
$dotNetFilename = "NDP471-KB4033342-x86-x64-AllOS-ENU.exe"

#Script Run Credentials
$secUser = "fslogix.local\Script.Admin"
$secPasswd = "V3ryS3cur3Sc1ptAdm1n"

#Get Current Script Folder
$currentFolder = Get-Script-Directory

##Log File configuration
$logLoc = "C:\CustomPOSH_Logs"
$null = New-Item -ItemType Directory -Path $logLoc -Force

##Download Location
$downloadLoc = "C:\CustomPOSH_Downloads"

##Location for files to be downloaded
$downloadFiles = @()
$downloadFiles += ("https://publicfiledownloads.blob.core.windows.net/downloads/NDP471-KB4033342-x86-x64-AllOS-ENU.exe")

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

#Set AutoLogon
Set-AutoLogon -DefaultUsername $secUser -DefaultPassword $secPasswd -Script "C:\Windows\System32\WindowsPowershell\V1.0\powershell.exe -ExecutionPolicy Unrestricted -File ""$currentFolder\CitrixSessionServerConfig.ps1""" -AutoLogonCount 1

& shutdown -r -t 05