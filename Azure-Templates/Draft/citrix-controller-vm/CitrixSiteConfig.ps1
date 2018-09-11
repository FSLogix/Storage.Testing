##Citrix Farm Configuration Script
# Get the script parameters 
# secUser must contain the domain and the user for a Domain Admin
# fslogix.local\fsadmin is passed by the AzureRM template by default

param(
    [string] $secUser, 
    [string] $secPasswd
)

#Pull in the admin credentials from Azure and use them to create a PSCredentialsObject
$userPasswd = ConvertTo-SecureString -String $secPasswd -AsPlainText -Force
$myCreds = New-Object System.Management.Automation.PSCredential ($secUser,$userPasswd)

##XenDesktop Farm Creation Variables
$dbserver="fsx-xdc-01.fslogix.local" 
$sitename="XDSite"
$licenseserver="fsx-xdc-01.fslogix.local"
$Citrixadmingroup="fslogix.local\domain admins"
$sitename_Site = "$sitename-Site"
$sitename_Monitor = "$sitename-Monitoring"
$sitename_Logging = "$sitename-Logging"

#Run powershell to configure the farm
asnp citrix*
new-xddatabase -sitename $sitename -Datastore Site -DatabaseServer $dbserver -databasename $sitename_Site -DatabaseCredentials $myCreds
new-xddatabase -sitename $sitename -Datastore Logging -DatabaseServer $dbserver -databasename $sitename_Logging -DatabaseCredentials $myCreds
new-xddatabase -sitename $sitename -Datastore Monitor -DatabaseServer $dbserver -databasename $sitename_Monitor -DatabaseCredentials $myCreds
new-XDSite -DatabaseServer $dbserver -loggingdatabasename $sitename_Logging -monitordatabasename $sitename_Monitor -sitedatabasename $sitename_Site -sitename $sitename
Set-XDLicensing -licenseserveraddress $licenseserver -licenseserverport 27000
new-adminadministrator -name $Citrixadmingroup
Add-adminright -administrator $Citrixadmingroup -role 'Full Administrator' -All
 
 