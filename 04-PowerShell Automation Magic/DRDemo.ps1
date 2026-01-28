# Automation Dream Team - DEMO DAY!

<#
    Disaster Recovery Readiness Check
    Jordan Sassi
#>

#---------------------------------------SETUP---------------------------

# Demo Environment Variables
$sqlInstances = @("localhost\DEMO", "localhost\DEMO2017", "localhost\DEMO2019")
$pathPresentationFiles = "C:\Presentations\DemoDBAVUG"
$pathToExportInstance = "C:\DbatoolsExport"
$pathSQLBackups = "C:\DemoBackups"
$pathReplicatedBackups = "C:\DemoBackupsReplicated"


# Instance and database to store output data
$writeSqlInstance = "localhost\DEMO"
$writeSqlDatabase = "DreamTeamDemo"

# Instance to test restore on
$restoreSqlInstance = "localhost\DEMO2017"
$restoreSqlInstancePath = "C:\DbatoolsExport\localhost-DEMO2017"

# DEMO env setup/reset
Set-Location $pathPresentationFiles
.\DemoInit.ps1

#----------------------------------- BACKUPS -----------------------------------

<#
    What do we need to know about our backups for DR?
    
        -Backups have run
        -Backups have been replicated 
        -Backups have been tested 
#>

# Test that backups have been taken *at all*
Invoke-DbcCheck -Check Backup -SqlInstance $sqlInstances 

# Store the results in a table, so we can use it in reports and dashboards
Invoke-DbcCheck -Check Backup -SqlInstance $sqlInstances -PassThru | Convert-DbcResult | Write-DbcTable -SqlInstance $writeSqlInstance -Database $writeDbaChecksDatabase -Table $writeDbaChecksTable




# Test that backups have been replicated

<# 
    example 1 - check that your replication job succeeded (ideally you are checking that all jobs succeed)
#>
Invoke-DbcCheck -Check FailedJob -SqlInstance $sqlInstances 

Get-DbaAgentJob -SqlInstance $sqlInstances | Select-Object InstanceName, Name, LastRunDate, LastRunOutcome | Where-Object Name -eq 'Replicate SQL Backups' 



<# 
    example 2 - check that today's backup files exist in the destination 
#>
Get-ChildItem -Path $pathSQLBackups | Where-Object {([datetime]::now.Date -eq $_.lastwritetime.Date)};

# compare files - returns nothing if matching, returns differences if found
$localBackups = Get-ChildItem -Recurse -path $pathSQLBackups
$replicatedBackups = Get-ChildItem -Recurse -path $pathReplicatedBackups
Compare-Object -ReferenceObject $localBackups -DifferenceObject $replicatedBackups


#----------------------------------- DBCC CHECKDB -----------------------------------

<#
    For our backups to be useful, our data needs to be checked for corruption.
    A backup we can't restore is not a backup!
#>

# Test that integrity checks have run/succeeded
Invoke-DbcCheck -Check LastGoodCheckDb -SqlInstance $sqlInstances 

# Store the results in a table, so we can use it in reports and dashboards
Invoke-DbcCheck -Check LastGoodCheckDb -SqlInstance $sqlInstances -PassThru | Convert-DbcResult | Write-DbcTable -SqlInstance $writeSqlInstance -Database $writeDbaChecksDatabase -Table $writeDbaChecksTable


<#
    More robust test of backups - Test-DbaLastBackup
    This dbatools command checks for a backup, tests the restore, AND runs DBCC checks.

    Don't run this in your production instances without understanding what it does! 
    By default, it will run tests and restore copies of each of your databases on the SAME SERVER. 

    https://dbatools.io/Test-DbaLastBackup/
#>
Test-DbaLastBackup -SqlInstance $sqlInstances 

# Store the results in a table, so we can use it in reports and dashboards
$lastBackup = Test-DbaLastBackup -SqlInstance $sqlInstances
Write-DbaDbTableData -InputObject $lastBackup -SqlInstance $writeSqlInstance -Database $writeSqlDatabase -Table "[dbo].[LastBackupResults]" -AutoCreateTable


#----------------------------------- Restore Files -----------------------------------

<#
    Database backups alone are not DR. 
    
    We saw a great demo of Export-DbaInstance, just now! 
    Lets just check that our files are still there, from today.

    Export-DbaInstance -SqlInstance $sqlInstances -Exclude Credentials, LinkedServers -Path $pathToExportInstance -Force
#>

# Check that we have restore files from today
Get-ChildItem -Path $pathToExportInstance -Recurse | Select-Object Directory, FullName, LastWriteTime, Name | Where-Object {([datetime]::now.Date -eq $_.lastwritetime.Date)};

# Store the results in a table, so we can use it in reports and dashboards
$lastConfig = Get-ChildItem -Path $pathToExportInstance -Recurse | Select-Object Directory, FullName, LastWriteTime, Name | Where-Object {([datetime]::now.Date -eq $_.lastwritetime.Date)};
Write-DbaDbTableData -InputObject $lastConfig -SqlInstance $writeSqlInstance -Database $writeSqlDatabase -Table "[dbo].[LastConfigExport]" -AutoCreateTable



#--------------------------------------- Now what? --------------------------------------
<#
    We have all our backups, we've copied our backups to a safe secondary location, and we have tested 
        using both VerifyOnly and Test-DbaLastBackup. 

    We have exported all our restore files and configuration data with Claudio, 
        and checked it in to source control.

    We need to test our DR process! If we don't test our DR, we don't really have DR.

    Some extra fun pester checks you can use around your recovery testing by Chrissy Lemaire 
        can be found at sqlps.io/doomsday
#>

# Test your recovery process
$files = Get-ChildItem -Path $restoreSqlInstancePath 
$files | ForEach-Object {
    Write-Output "Restoring $PSItem"
    Invoke-DbaQuery -File $PSItem -SqlInstance $restoreSqlInstance -ErrorAction Ignore -Verbose
}



#-------------------------------- DOCUMENTATION & SUMMARY -------------------------------------
<#
    Look familiar?
        # Store the results in a table, so we can use it in reports and dashboards

    Anything you save to a table, you can report on. Use reporting tools to your advantage, and
        keep a living automated document of your DR status to accompany your process documentation
        and playbooks.

    If you are relying on manual processes and a sleepy human for DR, you do not have DR.
    If you don't document your DR, you do not have DR.
    If you don't test your DR, you do not have DR.

    Automate all the things - the sleepy human and thier bosses will thank you.
#>


