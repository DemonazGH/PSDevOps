function Copy-EcsRstFilesToLocals {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position = 0, HelpMessage = "Unique pipeline id to check that all restore steps use correct initialization variables")]
        [string]$restorePipelineID_arg
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
        try {
            $Start = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
            $StartTime = $(get-date)

            # Read global variables
            Get-EcsRstGlobalVariables

            Write-EcsRstOutput ("********************************************************************************") Cyan
            Write-EcsRstOutput ("*** [$fn]") Cyan
            Write-EcsRstOutput ("*** Started at : $Start") Cyan
            Write-EcsRstOutput ("*** Pipeline ID: $restorePipelineID_arg") Cyan
            Write-EcsRstOutput ("*** ----------------------------------------------------------------------------") Cyan

            # Check pipeline ID
            if (($null -eq $restorePipelineID_arg) -Or ($restorePipelineID_arg -eq '')) {
                throw "Error: Pipeline ID cannot be empty"
            }
            if ($restorePipelineID_arg -ne $global:Restore_PipelineID) {
                throw "Pipeline ID specified ($restorePipelineID_arg) is different from the pipeline ID used when initializing the restore ($global:Restore_PipelineID). Make sure you run the initialization script at the beginning"
            }

            # Read the environments topology
            Write-EcsRstOutput ("Read the environments topology")

            Write-EcsRstOutput ("Search for the short name in the topology: $global:Restore_EnvShortName")
            $environment = Get-CurrentEnvironmentConfig
            if ($null -eq $environment) {
                throw "ERROR: Environment was not found in the topology: '$global:Restore_EnvShortName'"
            }
            Write-EcsRstOutput ("Found. Environment description: '$($environment.Description)'")
            Write-EcsRstOutput (" ")


            [string]$dbServer = $environment.DatabaseServerName
            [string]$dbInstance  = $dbServer

            Write-EcsRstOutput ("DB server name  : $dbServer")
            Write-EcsRstOutput ("DB instance name: $dbInstance")
            Write-EcsRstOutput (" ")
  
            if ((!$global:Restore_SQLBackupFile)) {
                throw "ERROR: SQL backup file to be restored is empty"
            }

            # Check that sql backup file exists
            Write-EcsRstOutput ("SQL backup file: $global:Restore_SQLBackupFile")
            if ($global:Restore_SQLBackupFile) {
                if (-Not(Test-Path -Path "$global:Restore_SQLBackupFile" -PathType Leaf)) {
                    throw "ERROR: SQL backup file to be restored not found: '$global:Restore_SQLBackupFile'"
                }
            }
            Write-EcsRstOutput (" ")

            # Checking DB server available drives
            Write-EcsRstOutput ("Checking available drives on DB server: '$dbServer'")
            [string]$defaultDBServerLocalPath = "F:\"
            [string]$backupLocalPathShared = "\\" + $dbServer + "\" + $defaultDBServerLocalPath.Replace(":\", "$\")
            if (-Not(Test-Path -Path "$backupLocalPathShared")) {
                Write-EcsRstOutput ("$defaultDBServerLocalPath drive doesn't exist!")
                $defaultDBServerLocalPath = "E:\"
                $backupLocalPathShared = "\\" + $dbServer + "\" + $defaultDBServerLocalPath.Replace(":\", "$\")
                if (-Not(Test-Path -Path "$backupLocalPathShared")) {
                    Write-EcsRstOutput ("$defaultDBServerLocalPath drive doesn't exist!")
                    $defaultDBServerLocalPath = "D:\"
                    $backupLocalPathShared = "\\" + $dbServer + "\" + $defaultDBServerLocalPath.Replace(":\", "$\")
                    if (-Not(Test-Path -Path "$backupLocalPathShared")) {
                        Write-EcsRstOutput ("$defaultDBServerLocalPath drive doesn't exist!")
                        throw "ERROR: No available drive found on DB server '$dbServer'. Drives scanned: F, E, D"
                    }
                    else {
                        Write-EcsRstOutput ("$defaultDBServerLocalPath drive found")
                    }
                }
                else {
                    Write-EcsRstOutput ("$defaultDBServerLocalPath drive found")
                }
            }
            else {
                Write-EcsRstOutput ("$defaultDBServerLocalPath drive found")
            }
            Write-EcsRstOutput (" ")
            
            # Get SQL restore file local path
            if ($global:Restore_SQLBackupFile) {
                [string]$backupFileWithoutPath = Split-Path $global:Restore_SQLBackupFile -leaf
                [string]$backupFileLocal       = $defaultDBServerLocalPath + $backupFileWithoutPath
                [string]$backupFileLocalShared = $backupLocalPathShared + $backupFileWithoutPath
                Write-EcsRstOutput ("[SQL backup]") Magenta
                Write-EcsRstOutput ("Original SQL backup file      : $global:Restore_SQLBackupFile")
                Write-EcsRstOutput ("Local SQL backup file         : $backupFileLocal")
                Write-EcsRstOutput ("Local SQL backup file (shared): $backupFileLocalShared")
                Write-EcsRstOutput (" ")
            }

            [bool]$copySQLBackup = $true
            $global:Restore_SQLBackupFileLocal    = $backupFileLocal
            <#
            if ($sEnvCurrent.ToUpper() -eq $dbServer.ToUpper()) {
                $copySQLBackup = $false
                Write-EcsRstOutput ("Warning! The agent is running on the environment DB server. The SQL backup file will not be copied to save time and disk space!") Green
            }
            else {
                Write-EcsRstOutput ("Warning! The agent is not running on the environment DB server. The SQL backup file will be copied to the local DB server folder!") Yellow
            }
            #>
            $copySQLBackup = $false
            Write-EcsRstOutput ("Warning! The SQL database restore will be run on '$env:COMPUTERNAME'. The SQL backup file will not be copied to save time and disk space!") Green

            # Delete existing files
            # SQL backup
            if ($copySQLBackup) {
                Write-EcsRstOutput ("Deleting any existing SQL backup files at: $backupLocalPathShared")
                [string]$FilesFilter = "*.bak"
                $filesList = Get-ChildItem -Path $backupLocalPathShared -Filter $FilesFilter
                foreach ($file in $filesList) {
                    $fullFilePath = $backupLocalPathShared + "\" + $file
                    Write-EcsRstOutput ('.  - Deleting existing SQL backup file: ' + $fullFilePath)
                    Remove-Item -Path $fullFilePath -Force
                    if (Test-Path -Path $fullFilePath -PathType Leaf) {
                        throw "ERROR: Unable to delete existing backup file: $fullFilePath"
                    }
                }
            }

            # Copy files
            # SQL backup
            if ($copySQLBackup) {
                Write-EcsRstOutput ("Copying backup file") Magenta
                Write-EcsRstOutput (".  - from: $global:Restore_SQLBackupFile")
                Write-EcsRstOutput (".  - to  : $backupFileLocalShared")
                Write-EcsRstOutput ("Warning! This can take about an hour") Yellow
                Copy-Item -Path $global:Restore_SQLBackupFile -Destination $backupFileLocalShared
                if (-Not(Test-Path -Path "$backupFileLocalShared" -PathType Leaf)) {
                    throw "ERROR: unable to copy file to: '$backupFileLocalShared'"
                }
                Write-EcsRstOutput (" ")
            }

            if (!$copySQLBackup) {
                $global:Restore_SQLBackupFileLocal = $global:Restore_SQLBackupFile    
            }

            #Save global variables
            Write-EcsRstGlobalVariables

            # Show elapsed time
            $elapsedTime = $(get-date) - $StartTime
            $totalTime = "{0:HH:mm:ss.fff}" -f ([datetime]$elapsedTime.Ticks)
            Write-EcsRstOutput (" ")
            Write-EcsRstOutput ('*** Time elapsed: ' + $totalTime.ToString()) Cyan
            Write-EcsRstOutput ("********************************************************************************") Cyan
            Write-EcsRstOutput (" ")
            Write-EcsRstOutput (" ")
        }
        catch {
            $errorMessage = $_
            # Send the error to the log
            Write-EcsRstOutput ("Error: " + $errorMessage) Red
            # Register a failed step
            Register-EcsRstStepFailure -errorMessage_arg "$errorMessage" -restoreStep_arg $fn
            
            throw $errorMessage
        }
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
Copy-EcsRstFilesToLocals -restorePipelineID_arg 'AAA'
<##> 