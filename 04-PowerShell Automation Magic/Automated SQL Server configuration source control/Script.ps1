# Where we will get the list of servers

$centralServer = "centralServer"
$centralDatabase = "centralDatabase"
$query = "SELECT ConnString FROM <table>"

# Get the list of servers

$ServerList = Invoke-DbaQuery -SqlInstance $centralServer -Database $centralDatabase -Query $query | Select-Object -ExpandProperty ConnString

$instancesPath = "$PSScriptRoot\Instances"
$tempPath = "$instancesPath\temp"

# Change location to be able to run GIT commands on the local repository

Set-Location -Path $PSScriptRoot

# get folder up-to-date
git pull


# Create/clear temp folder
if (Test-Path -Path $tempPath) {
    # Clean the folder
	Get-ChildItem $tempPath | Remove-Item -Force -Recurse -Confirm:$false
} else {
    $null = New-Item -Path $tempPath -ItemType Directory
}

<#
    Databases -> Exclude databases will not script the RESTORE statements for last backup. We don't need this because we use a 3rd party tool and this was slowing down the execution
    PolicyManagement and ReplicationSettings -> We don't use
    Credentials and LinkedServers -> We script as a second step to hide passwords (because -ExcludePassword will also hide hashed ones from logins, and this we want to keep)
#>
$excludeObjects = "Databases", "PolicyManagement", "ReplicationSettings", "Credentials", "LinkedServers"

foreach($server in $ServerList) {
    # Run the export and get a collection of files generated
    $outputDirectory = Export-DbaInstance -SqlInstance $server -Path $tempPath -Exclude $excludeObjects -NoPrefix

    # Extract the directory full path of the export to use next
    $instanceOutDir = $outputDirectory.Directory | Select-Object -ExpandProperty FullName -Unique

    # Export credentials and LinkedServers but excluding the password. Output to same folder
    Export-DbaCredential -SqlInstance $server -FilePath "$instanceOutDir\Credentials.sql" -ExcludePassword
    Export-DbaLinkedServer -SqlInstance $server -FilePath "$instanceOutDir\LinkedServers.sql" -ExcludePassword
}

# Find .sql files where the name starts with a number and rename files to exclude numeric part "#-<NAME>.sql" (remove the "#-")
#Get-ChildItem -Path $tempPath -Recurse -Filter "*.sql" | Where-Object {$_.Name -match '^[0-9]+.*'} | Foreach-Object {Rename-Item -Path $_.FullName -NewName $($_ -split '-')[1] -Force}

# Remove the suffix "-datetime"
Get-ChildItem -Path $tempPath | Foreach-Object {Rename-Item -Path $_.FullName -NewName $_.Name.Substring(0, $_.Name.LastIndexOf('-')) -Force}

# Copy the folders/files from the temp directory to one level up (overwrite)
Copy-Item -Path "$tempPath\*" -Destination $instancesPath -Recurse -Force

# Clean-up temp folder
Get-ChildItem $tempPath | Remove-Item -Force -Recurse -Confirm:$false


# Add/commit/push the changes
git add .
git commit -m "Export-DbaInstance @ $((Get-Date).ToString("yyyyMMdd-HHmmss"))"
git push