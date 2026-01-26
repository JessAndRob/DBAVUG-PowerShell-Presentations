<#
    If you want to read more about it, I have written a couple of blog posts:
        https://claudioessilva.eu/2020/06/02/Backup-your-SQL-instances-configurations-to-GIT-with-dbatools-Part-1/
        https://claudioessilva.eu/2020/06/04/Backup-your-SQL-instances-configurations-to-GIT-with-dbatools-Part-2-Add-parallelism/
    
    NOTE: At the time of the writing of these blog posts, Export-DbaInstance was appending a number prefix to the file names.
    This has changed, and now, by default, it does not append a number prefix.

    You can also check the official documentation here:
        https://dbatools.io/Export-DbaInstance/

#>

<#
    The list of servers
#>
$sqlInst1 = "localhost,1433"
$sqlInst2 = "localhost,14334"
$sqlInstances = @($sqlInst1, $sqlInst2)

# Get SQL Credentials
$sqlCred = Get-Credential -UserName "sqladmin" -Message "Enter password for SQL Admin user" 

<# 
    Define paths
     - instancesPath: Where the Instances folders will be stored (this is a git tracked folder)
     - tempPath: Temporary folder where the instances will be exported before moving to instancesPath 
     (not git tracked. It was added to .gitignore)
#>
$instancesPath = "C:\Git\dbatools-demos\GitExportDbaInstance\Export\Instances"
$tempPath = "$instancesPath\temp"

<#
    Create/clear temp folder
#>
if (Test-Path -Path $tempPath) {
    # Clean the folder
	Get-ChildItem $tempPath | Remove-Item -Force -Recurse -Confirm:$false
} else {
    $null = New-Item -Path $tempPath -ItemType Directory
}


<#
    All in! 
    (Don't be this person in your environments...this is a demo after all)
#>
Export-DbaInstance -SqlInstance $sqlInstances -SqlCredential $sqlCred -Path $tempPath


<#
    Do you have doubts?
    Want to know more about the parameters and options of Export-DbaInstance?
    You can always run the help command to get more information:
#>
Get-Help Export-DbaInstance -ShowWindow


<#
    Create/clear temp folder
#>
if (Test-Path -Path $tempPath) {
    # Clean the folder
	Get-ChildItem $tempPath | Remove-Item -Force -Recurse -Confirm:$false
} else {
    $null = New-Item -Path $tempPath -ItemType Directory
}


<#
    This will create all scripts in the D:\temp folder. A folder named “devInstance-{date}” will be created. 
    In this folder, you will find 1 file per ‘object type’. 
#>
$excludeObjects = "Databases", "PolicyManagement", "ReplicationSettings", "Credentials", "LinkedServers"
Export-DbaInstance -SqlInstance $sqlInstances -SqlCredential $sqlCred -Path $tempPath -Exclude $excludeObjects -NoPrefix


<#
    git tracks differences.
    If we leverage on the default behavior of Export-DbaInstance, every time we run it, new folders will be 
    created with the date appended to the folder name.

    Because of that, we need to do some renaming of the files/folders to remove the datetime part.
#>
Get-ChildItem -Path $tempPath | Foreach-Object {Rename-Item -Path $_.FullName -NewName $_.Name.Substring(0, $_.Name.LastIndexOf('-')) -Force}

<#
    Copy the folders/files from the temp directory to one level up (overwrite)
#>
Copy-Item -Path "$tempPath\*" -Destination $instancesPath -Recurse -Force




<#
    Change some sp_configure settings to generate a drift in the scripts.

    NOTE: Change to the opposite value (0/1) of the current one to make sure there is a difference.
#>
Set-DbaSpConfigure -SqlInstance $sqlInstances -SqlCredential $sqlCred -Name BackupChecksumDefault -Value 1
Set-DbaSpConfigure -SqlInstance $sqlInstances -SqlCredential $sqlCred -Name DefaultBackupCompression -Value 1


<#
    Create/clear temp folder
#>
if (Test-Path -Path $tempPath) {
    # Clean the folder
	Get-ChildItem $tempPath | Remove-Item -Force -Recurse -Confirm:$false
} else {
    $null = New-Item -Path $tempPath -ItemType Directory
}

<#
    Run Export-DbaInstance again
#>
$excludeObjects = "Databases", "PolicyManagement", "ReplicationSettings", "Credentials", "LinkedServers"
Export-DbaInstance -SqlInstance $sqlInstances -SqlCredential $sqlCred -Path $tempPath -Exclude $excludeObjects -NoPrefix


<#
    Remove the suffix "-datetime"
#>
Get-ChildItem -Path $tempPath | Foreach-Object {Rename-Item -Path $_.FullName -NewName $_.Name.Substring(0, $_.Name.LastIndexOf('-')) -Force}

<#
    Copy the folders/files from the temp directory to one level up (overwrite)
#>
Copy-Item -Path "$tempPath\*" -Destination $instancesPath -Recurse -Force


# Add/commit/push the changes
<#
    GIT commands I’m using

    Here are the 3 git commands that I’m using:
        - git add . -> Will stage all changes for the next commit
        - git commit -m"some message" -> Will do the commit of the changes with a specific message
        - git push -> Will push the changes to the central repository

    NOTE: We will use one more in our script before running these 3 commands:
        - git pull -> Will get the latest changes from the central repository to make sure we are up-to-date before pushing our changes
#>

git add .
git commit -m "Export-DbaInstance @ $((Get-Date).ToString("yyyyMMdd-HHmmss"))"
git push


<#
    Create/clear temp folder
#>
if (Test-Path -Path $tempPath) {
    # Clean the folder
	Get-ChildItem $tempPath | Remove-Item -Force -Recurse -Confirm:$false
} else {
    $null = New-Item -Path $tempPath -ItemType Directory
}



<#
    Other useful examples
#>

<#
    Exclude Passwords

    If this switch is used, the scripts will not include passwords for Credentials, LinkedServers or Logins.

    If you run with this switch and if you open the scripts, you will see that for:
        - Logins: No hashed password is present
        - Credentials & LinkedServers will have their clear text passwords replaced by ‘EnterStrongPasswordHere’ and ‘#####’ respectively.
#>
Export-DbaInstance -SqlInstance $sqlInst2 -Path $tempPath -ExcludePassword


<#
    You can (and should) also combine this with the -Exclude parameter to exclude Credentials and LinkedServers from the main export
    and then export them separately with the -ExcludePassword switch.
#>
Export-DbaCredential -SqlInstance $server -FilePath "$tempPath\Credentials.sql" -ExcludePassword
Export-DbaLinkedServer -SqlInstance $server -FilePath "$tempPath\LinkedServers.sql" -ExcludePassword