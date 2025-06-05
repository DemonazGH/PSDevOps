function Restore-EcsSqlDataDatabaseFromFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Short name of the environment")]
        [string]$envShortName_arg
       ,[Parameter(Mandatory = $true, Position = 1, HelpMessage = "Path to a backup file")]
        [string]$backupFile_arg
    )

    #region Standard Start Block
    $Private:Tmr = New-Object System.Diagnostics.Stopwatch; $Private:Tmr.Start()
    $MyParams = $PSBoundParameters | Out-String
    $ErrorActionPreference = "Stop"; $fn = '{0}' -f $MyInvocation.MyCommand
    $LogSource = $fn; $EntryType = "4" #1 Error, 2 Warning, 4 Information
    $StartTime = Get-Date((Get-Date).ToUniversalTime()) -Format HH:mm:ss
    $BeginMessage = "[$env:COMPUTERNAME-$StartTime" + "z]-[$fn]: Begin Process"    
    #endregion

    try {
        Push-Location
        Write-Host $BeginMessage
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource "$LogSource" -EventID 1000 -Message "$BeginMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1

        ###### Start Script Here 
        $Start = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
        $StartTime = $(get-date)

        Write-Host "********************************************************************************"
        Write-Host "*** [$fn]"
        Write-Host "*** Started at    : $Start"
        Write-Host "*** Env short name: $envShortName_arg"
        Write-Host "*** Backup file   : $backupFile_arg"
        Write-Host "********************************************************************************"
        
        [string]$SQLQuery_RemoveReplication  = "USE master  
                                                EXEC sp_removedbreplication '<DB_Name>'"
        [string]$SQLQuery_SetSimpleMode      = "ALTER DATABASE [<DBName>] SET RECOVERY SIMPLE"
        [string]$SQLQuery_CreateReporterUser = "IF EXISTS (SELECT [name] FROM [sys].[database_principals] WHERE [type] in (N'G', N'U') AND [name] = N'SQLReporter')
                                                Begin
                                                CREATE USER [SQLReporter] FOR LOGIN [SQLReporter]
                                                ALTER ROLE [db_datareader] ADD MEMBER [SQLReporter]
                                                End"
        [string]$SQLQuery_GetDatabaseState   = "SELECT State, State_desc FROM sys.databases WHERE Name = N'<DBName>'"

        # Read the environments topology
        Write-Host "Read the environments topology"
        Write-Host "Search for the short name in the topology: $envShortName_arg"
        $environment = Get-CurrentEnvironmentConfig

        if ($null -eq $environment) {
            throw "ERROR: Environment was not found in the topology: '$envShortName_arg'"
        }
        Write-Host "Found. Environment description: '$($environment.Description)'"
        Write-Host " "

        Write-Host "'LockDataRefresh' property value: $($environment.LockDataRefresh)"
        if ($environment.LockDataRefresh) {
            throw "ERROR: 'LockDataRefresh' property is set for environment '$($environment.Name)'. No data refresh is possible for the environment!"
        }

        [string]$dbServer     = $environment.DatabaseServerName
        [string]$dbInstance   = $dbServer
        [string]$dbName       = $environment.DatabaseName

        [string]$sEnvCurrent  = $env:COMPUTERNAME
        [string]$sEnvDBServer = $environment.DatabaseServerName

        [bool]$onDBServer = $false
        if ($sEnvCurrent.Split('.')[0] -eq $sEnvDBServer.Split('.')[0]) {
            [bool]$onDBServer = $true
        }

        Write-Host "DB server name  : $dbServer"
        Write-Host "DB instance name: $dbInstance"
        Write-Host "DB name         : $dbName"
        Write-Host "Script is running directly on DB server: $onDBServer"
        Write-Host " "
        Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        Write-Host "Retieving SQL Server parameters"
        Write-Host " "
        try {
            # Restart SQL server only if there are no SQL nodes!!!
            [boolean]$sqlFailoverCluster = $false
            
            if ($environment.SQLNode.Length -gt 0) {
                $sqlFailoverCluster = $true
                Write-Host "Warning! SQL failover cluster was detected"
            }            
            
            # Read SQL parameters from registry            
            if ($onDBServer) {
                Write-Host "Reading registry values locally ('$sEnvDBServer')"
            }
            else {
                Write-Host "Reading registry values remotely on '$sEnvDBServer'"
            }
            
            # Get SQL server default registry instance
            $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $sEnvDBServer)
            $keyPath  = "SOFTWARE\\Microsoft\\Microsoft SQL Server\\Instance Names\\SQL"
            $keyValue = "MSSQLSERVER"
            if (-Not([string]::IsNullOrEmpty($environment.DatabaseInstanceName))) {
                [string]$envInstance = $environment.DatabaseInstanceName
                [int]$idx = $envInstance.LastIndexOf("\")
                if ($idx -ne -1) {
                    $keyValue = $envInstance.Substring($idx+1, $envInstance.Length - $idx - 1)
                }
                else {
                    $keyValue = $envInstance
                }
            }
            $RegKey= $Reg.OpenSubKey($keyPath)
            Write-Host "Reading registry. Path '$keyPath', name '$keyValue'"
            $regMSSQLSERVER = $RegKey.GetValue($keyValue)
            Write-Host "Value read: $regMSSQLSERVER"
            if (!$regMSSQLSERVER) {
                throw "ERROR: Unable to find the default SQL instance in registry. Key: '$keyPath'. Value: '$keyValue'"
            }
            Write-Host "Current SQL instance in registry: '$regMSSQLSERVER'"
            Write-Host " "
    
            # Get Data path
            $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $sEnvDBServer)

            $keyPath = "SOFTWARE\\Microsoft\\Microsoft SQL Server\\" + $regMSSQLSERVER + "\\MSSQLServer"
            $keyValue = "DefaultData"            
            $RegKey= $Reg.OpenSubKey($keyPath)
            Write-Host "Reading registry. Path '$keyPath', name '$keyValue'"
            $regDataPath = $RegKey.GetValue($keyValue)
            Write-Host "Value read: $regDataPath"
            if (!$regDataPath) {
                Write-Host "Warning: Unable to find the default SQL data folder in registry. Key: '$keyPath'. Value: '$keyValue'"

                $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $sEnvDBServer)
                $keyPath = "SOFTWARE\\Microsoft\\Microsoft SQL Server\\" + $regMSSQLSERVER + "\\Setup"
                $keyValue = "SQLDataRoot"
                $RegKey= $Reg.OpenSubKey($keyPath)
                Write-Host "Reading registry. Path '$keyPath', name '$keyValue'"
                $regDataPath = $RegKey.GetValue($keyValue)
                Write-Host "Value read: $regDataPath"
                if (!$regDataPath) {
                    throw "ERROR: Unable to find the default SQL data folder in registry. Key: '$keyPath'. Value: '$keyValue'"
                }
                $regDataPath = $regDataPath + "\DATA"
            }
            [string]$sqlDataPath       = $regDataPath

            [string]$sqlDataPathShared = "\\" + $sEnvDBServer + "\" + $sqlDataPath.replace(":\", "$\")
            Write-Host "SQL server Data path       : '$sqlDataPath'"
            Write-Host "SQL server Data path shared: '$sqlDataPathShared'"
            try {
                [string]$sqlDataDrive = Split-Path -Path $sqlDataPath -Qualifier
            }
            catch {
                [string]$sqlDataDrive = ""
                Write-Host "Unable to retrieve drive letter from the data file path: $_"
            }
            Write-Host "SQL server Data drive      : '$sqlDataDrive'"
            Write-Host " "
    
            # Get Log path
            $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $sEnvDBServer)
            $keyPath = "SOFTWARE\\Microsoft\\Microsoft SQL Server\\" + $regMSSQLSERVER + "\\MSSQLServer"
            $keyValue = "DefaultLog"
            $RegKey= $Reg.OpenSubKey($keyPath)
            Write-Host "Reading registry. Path '$keyPath', name '$keyValue'"
            [string]$sqlLogPath       = $RegKey.GetValue($keyValue)
            Write-Host "Value read: $sqlLogPath"
            [string]$sqlLogPathShared = "\\" + $sEnvDBServer + "\" + $sqlLogPath.replace(":\", "$\")
            if (!$sqlLogPath) {
                throw "ERROR: Unable to find the default SQL log folder in registry. Key: '$keyPath'. Value: '$keyValue'"
            }
            Write-Host "SQL server Log path       : '$sqlLogPath'"
            Write-Host "SQL server Log path shared: '$sqlLogPathShared'"
            try {
                [string]$sqlLogDrive = Split-Path -Path $sqlLogPath -Qualifier
            }
            catch {
                [string]$sqlLogDrive = ""
                Write-Host "Unable to retrieve drive letter from the log file path: $_"
            }
            Write-Host "SQL server Log drive      : '$sqlLogDrive'"
            Write-Host " "
                
            # Get SQL agent service name
            $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $sEnvDBServer)
            $keyPath = "SOFTWARE\\Microsoft\\Microsoft SQL Server\\Services\\SQL Agent"
            $keyValue = "Name"
            $RegKey= $Reg.OpenSubKey($keyPath)
            Write-Host "Reading registry. Path '$keyPath', name '$keyValue'"
            $regAgentServiceName = $RegKey.GetValue($keyValue)
            Write-Host "Value read: $regAgentServiceName"
            if (!$regAgentServiceName) {
                throw "ERROR: Unable to find the SQL agent service name in registry. Key: '$keyPath'. Value: '$keyValue'"
            }
            Write-Host "SQL server agent service name: '$regAgentServiceName'"
            Write-Host " "
    
            # Get SQL server service name
            $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $sEnvDBServer)
            $keyPath = "SOFTWARE\\Microsoft\\Microsoft SQL Server\\Services\\SQL Server"
            $keyValue = "Name"
            $RegKey= $Reg.OpenSubKey($keyPath)
            Write-Host "Reading registry. Path '$keyPath', name '$keyValue'"
            $regSQLServiceName = $RegKey.GetValue($keyValue)
            Write-Host "Value read: $regSQLServiceName"
            if (!$regSQLServiceName) {
                throw "ERROR: Unable to find the SQL server service name in registry. Key: '$keyPath'. Value: '$keyValue'"
            }
            Write-Host "SQL server service name: '$regSQLServiceName'"
            Write-Host " "
    
            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
                if (!$sqlFailoverCluster) {
                Write-Host "Restarting SQL server and agent on '$sEnvDBServer'"
                Write-Host ".  - Stopping SQL server agent ($regAgentServiceName)"
                Stop-EcsWinServiceAny -service_arg $regAgentServiceName -computer_arg $sEnvDBServer -msgPrefix_arg ".    -" -doNotShowWrapperMessages
                Write-Host ".  - Stopping SQL server ($regSQLServiceName)"
                Stop-EcsWinServiceAny -service_arg $regSQLServiceName -computer_arg $sEnvDBServer -msgPrefix_arg ".    -" -doNotShowWrapperMessages
                Write-Host ".  - StartingSQL server ($regSQLServiceName)"
                Start-EcsWinServiceAny -service_arg $regSQLServiceName -computer_arg $sEnvDBServer -msgPrefix_arg ".    -" -doNotShowWrapperMessages
                Write-Host ".  - Starting SQL server agent ($regAgentServiceName)"
                Start-EcsWinServiceAny -service_arg $regAgentServiceName -computer_arg $sEnvDBServer -msgPrefix_arg ".    -" -doNotShowWrapperMessages
            }
            else {
                Write-Host "SQL server restart skipped because SQL failover cluster was detected"
            }
            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
            Write-Host " "
            
            # Remove any replication
            Write-Host "Removing any replication for database '$dbName' on '$dbInstance'"
            $SQLQuery = $SQLQuery_RemoveReplication.Replace("<DB_Name>", $dbName)
            try {
                $queryResult = Invoke-Sqlcmd -Query $SQLQuery -ServerInstance $dbInstance
            }
            catch {
                Write-Host "Query fail: $SQLQuery"
                Write-Host "Unable to remove replication: $_"
                Write-Host "The process will continue"
            } 
            Write-Host " "
            
            #Check if the database exists and force to single user mode
            #This is automatcially done by restore command, but sometimes does not work
            Write-Host "Deleting database '$dbName' on '$dbInstance'"
            try {
                Set-DbaDbState -SqlInstance $dbInstance -Database $dbName -Detached -Force
            }
            catch {
                Write-Host "Unable to delete database: $_"
                Write-Host "The process will continue"
            }
            Write-Host " "
    
            Write-Host "Deleting any existing database '$dbName' files on '$dbInstance'"
            # DB data file
            [string]$sqlDataFilePath = $sqlDataPathShared + "\" + $dbName + ".mdf"
            Write-Host "[Data file: $sqlDataFilePath]"
            if (Test-Path -Path $sqlDataFilePath -PathType Leaf) {
                Write-Host ".  - Deleting existing file"
                Remove-Item -Path $sqlDataFilePath -Force
                if (Test-Path -Path $sqlDataFilePath -PathType Leaf) {
                    throw "ERROR: Unable to delete existing file: $sqlDataFilePath"
                }
            }
            else {
                Write-Host ".  - no existing data file found"
            }
            Write-Host " "
    
            # DB log file
            [string]$sqlLogFilePath = $sqlLogPathShared + "\" + $dbName + "_log.ldf"
            Write-Host "[Log file: $sqlLogFilePath]"
            if (Test-Path -Path $sqlLogFilePath -PathType Leaf) {
                Write-Host ".  - Deleting existing file"
                Remove-Item -Path $sqlLogFilePath -Force
                if (Test-Path -Path $sqlLogFilePath -PathType Leaf) {
                    throw "ERROR: Unable to delete existing file: $sqlLogFilePath"
                }
            }
            else {
                Write-Host ".  - no existing log file found"
            }
            Write-Host " "
    
            # Try to delete any other data and log files on the same drive
            Write-Host " "
            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
            Write-Host "Try to delete any other data and log files on the same drive with the database name"
            if (-Not([string]::IsNullOrEmpty($sqlDataDrive))) {
                [string]$dataFileName = $dbName + ".mdf"
                [string]$sqlDataDrivePath = $sqlDataDrive + "\"
                Write-Host "> [DATA file]"
                Write-Host "> Searching for all files on drive '$sqlDataDrive' with name '$dataFileName'"
                Get-ChildItem -Path $sqlDataDrivePath -Include $dataFileName -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                    [string]$fileName = $_
                    Write-Host "> Deleting File: $fileName"
                    try {
                        Remove-Item -Path $fileName -Force
                        Write-Host ">     file was deleted"
                    }
                    catch {
                        Write-Host ">     unable to delete file!"
                    }
                }
            }
            else {
                Write-Host "> DATA file drive letter was not found. Skipping"
            }
            if (-Not([string]::IsNullOrEmpty($sqlLogDrive))) {
                [string]$logFileName = $dbName + "_log.ldf"
                [string]$sqlLogDrivePath = $sqlLogDrive + "\"
                Write-Host "> [LOG file]"
                Write-Host "> Searching for all files on drive '$sqlLogDrive' with name '$logFileName'"
                Get-ChildItem -Path $sqlLogDrivePath -Include $logFileName -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                    [string]$fileName = $_
                    Write-Host "> Deleting File: $fileName"
                    try {
                        Remove-Item -Path $fileName -Force
                        Write-Host ">     file was deleted"
                    }
                    catch {
                        Write-Host ">     unable to delete file!"
                    }
                }
            }
            else {
                Write-Host "> LOG file drive letter was not found. Skipping"
            }
            
            Write-Host "Try to delete any other data and log files on the same drive - 2nd attempt"
            $filePaths = @(
                "$sqlDataPathShared\$dbName*.mdf",
                "$sqlDataPathShared\$dbName_*.ndf",        # wildcard for all NDFs
                "$sqlLogPathShared\$dbName*.ldf"
            )
            foreach ($pat in $filePaths) {
                Write-Host "Cleaning up files matching: $pat"
                Get-ChildItem -Path $pat -File -ErrorAction SilentlyContinue |
                ForEach-Object {
                    Write-Host "Deleting $_"
                    Remove-Item -Path $_.FullName -Force -ErrorAction Stop
                }
            }

            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
            Write-Host " "
    
            Write-Host "Attempting to restore file: $backupFile_arg"
            Write-Host "DB server  : $dbServer"
            Write-Host "DB instance: $dbInstance"
            Write-Host "DB name    : $dbName"
            Write-Host "Data path  : $sqlDataPath"
            Write-Host "Log path   : $sqlLogPath"
            Write-Host " "
    
            [string]$backupFile = $backupFile_arg
            $RestoreTime = [System.Diagnostics.Stopwatch]::StartNew()        

            # Check if backup file exists
            if ([string]::IsNullOrEmpty($backupFile)) {
                throw "ERROR: SQL backup file is null"
            }
            if (-Not(Test-Path -Path $backupFile -PathType Leaf)) {
                throw "ERROR: SQL backup file doesn't exist: $backupFile"
            }

            Write-Host "Restore command for '$sEnvDBServer':"
            Write-Host "Restore-DbaDatabase -WithReplace -SqlInstance $dbInstance -Path $backupFile -DatabaseName $dbName -DestinationDataDirectory $sqlDataPath -DestinationLogDirectory $sqlLogPath -ReplaceDbNameInFile -ErrorAction Stop"

            $job = Invoke-Command $sEnvDBServer -ScriptBlock {
                Write-Host "Running as user: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
                try {
                    Restore-DbaDatabase -WithReplace -SqlInstance $Using:dbInstance -Path $Using:backupFile -DatabaseName $Using:dbName -DestinationDataDirectory $Using:sqlDataPath -DestinationLogDirectory $Using:sqlLogPath -ReplaceDbNameInFile -ErrorAction Stop
                }
                catch {
                    Write-Host "ERROR: Restore has failed. Actual error: $_"
                    throw $_
                }
            } -AsJob -JobName "SqlRestore"
            
            Start-Sleep 60 #Pause to give the next command time to capture correct results

            Get-EcsSqlRestoreProgress -Instance $dbInstance

            While ($job.State -eq 'Running') {
                Start-Sleep 1 #Changing this impacts the display rate
            }
            
            Write-Host " "
            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
            Write-Host "Process output:"
            try {
                $info = Receive-Job -Id ($job.Id)
                
                Write-Host $info
            }
            catch {
                Write-Host "Unable to retrieve process output: $_"
                Write-Host "The process will continue running because the issue is not critical"
            }
            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
            Write-Host " "

            # Once here, the job is no longer 'Running'—you can Receive-Job or handle success/failure
            if ($job.State -eq 'Failed') {
                $err = Receive-Job -Id $job.Id -ErrorAction SilentlyContinue
                throw "Restore job failed: $err"
            }

            if ($job.State -eq "Completed") {
                #Need to capture error better, fail if short duration
                if ( ($RestoreTime.Elapsed).TotalSeconds -le 200) {
                    throw "ERROR: Failed to complete correctly. Operation was too short: $(($RestoreTime.Elapsed).TotalSeconds) seconds"
                }
            } 

            # Wait for the DB to back online
            [int]$timeoutSeconds   = 600
            [int]$currentlyWaiting = 0
            [int]$refreshRate      = 30
            [bool]$dbIsOnline      = $false
            Write-Host " "
            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
            Write-Host "Waiting for database '$dbName' to back online"
            Write-Host "Timeout in seconds: $timeoutSeconds. Refresh rate in seconds: $refreshRate"
            [string]$SQLQuery = $SQLQuery_GetDatabaseState.Replace("<DBName>", $dbName)
            do {
                if ($currentlyWaiting -ge $timeoutSeconds) {
                    throw "ERROR: Database $dbName has not come online in $timeoutSeconds seconds"
                }

                try {
                    # Get DB state
                    #$queryResult = Invoke-DbaQuery -SqlInstance $Instance -Database $dbName -Query $SQLQuery -EnableException
                    $queryResult = Invoke-Sqlcmd -Query $SQLQuery -ServerInstance $dbInstance
                }
                catch {
                    Write-Host "Query fail: $SQLQuery"
                    throw $_
                }
                # DB is online
                if ($queryResult.State -eq 0) {
                    Write-Host "Database '$dbName' is online"
                    $dbIsOnline = $true
                }
                # DB is not online
                else {
                    if (($currentlyWaiting -eq 0) -Or ($currentlyWaiting % $refreshRate -eq 0)) {
                        Write-Host ".  - Database '$dbName' state: $($queryResult.State) ($($queryResult.State_desc))"
                    }
                }

                Start-Sleep -Seconds 1
                $currentlyWaiting++
            } while (!$dbIsOnline)

            # Set database mode to Simple
            Write-Host " "
            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
            Write-Host "Changing database '$dbName' mode to SIMPLE"
            [string]$SQLQuery = $SQLQuery_SetSimpleMode.Replace("<DBName>", $dbName)
            try {
                $queryResult = Invoke-Sqlcmd -Query $SQLQuery -ServerInstance $dbInstance
            }
            catch {
                Write-Host "Query fail: $SQLQuery"
                throw $_
            }

            # Create SQL reporter user (can fail)
            Write-Host " "
            Write-Host "Creating SQLReporter user for database '$dbName'"
            [string]$SQLQuery = $SQLQuery_CreateReporterUser
            try {
                $queryResult = Invoke-Sqlcmd -Query $SQLQuery -ServerInstance $dbInstance
            }
            catch {
                Write-Host "Query fail: $SQLQuery"
                Write-Host "Error: $_"
                Write-Host " "
                Write-Host "Warning! This query can fail in case of the user already exists. The process will continue"
            }
        }
        finally {  
            # Start Management Reporter services back
            try {
                foreach ($mrProcessServer in $mrProcessStoppedOn) {
                    Write-Host "$mrServiceProcess services was stopped on '$mrProcessServer'. Trying to start"
                    Start-EcsWinServiceAny -service_arg $mrServiceProcess -computer_arg $mrProcessServer
                }

                foreach ($mrApplicationServer in $mrApplicationStoppedOn) {
                    Write-Host "$mrServiceApplication services was stopped on '$mrApplicationServer'. Trying to start"
                    Start-EcsWinServiceAny -service_arg $mrServiceApplication -computer_arg $mrApplicationServer
                }
            }
            catch {
                Write-Host "An error occured when working with management reporter services: starting"
                Write-Host "ERROR: $_"
                Write-Host "The script will continue running"
            }    
        }
        
        # Show elapsed time
        $elapsedTime = $(get-date) - $StartTime
        $totalTime = "{0:HH:mm:ss.fff}" -f ([datetime]$elapsedTime.Ticks)
        Write-Host 'Time elapsed:' $totalTime.ToString()
        ######  End Script Here
    }
    catch {
        $Er = $_
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource $LogSource -EventId 3000 -Message "Failed with:`r`n$Er" -EntryType 1; Start-Sleep 1
        Write-Error "[$computerName]-[$fn]: !!! Failed with: `r`n$er!!!!"
    }
    finally {
        $TSecs = [math]::Round(($Private:Tmr.Elapsed).TotalSeconds); $Private:Tmr.Stop(); Remove-Variable Tmr
        $EndTime = Get-Date((Get-Date).ToUniversalTime()) -Format HH:mm:ss
        $EndMessage = "[$env:COMPUTERNAME-$EndTime"+"z]-[$fn]:[Elapsed Time: $TSecs seconds]: End Process"
        Write-Host $EndMessage
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource "$LogSource" -EventID 2000 -Message "$EndMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1
        Pop-Location
    }
    <#
    .SYNOPSIS
    .DESCRIPTION
    .EXAMPLE
    .EXAMPLE
    .LINK
#>
}
<## >
Restore-EcsSqlDataDatabaseFromFile -envShortName_arg 'IHFX' -backupFile_arg "F:\Build servers backup\BLD04\E\Builds\BlankDatabase\DV12_DW_R3WithConfigAMCR3_712 - WithUpdateObjectsAndNoPoland.bak"
<##>
