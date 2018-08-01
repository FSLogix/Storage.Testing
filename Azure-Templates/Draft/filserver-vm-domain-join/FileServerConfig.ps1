<# Custom Script for Windows to install a file from Azure Storage using the staging folder created by the deployment script #>
New-Item -Path "C:\ScriptRun" -ItemType Directory
"This is to prove that the powershell script ran" | Out-File -FilePath "C:\ScriptRun\IRan.txt"
