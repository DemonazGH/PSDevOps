function Restore-EcsRstSQLBackup {
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
    $StartTime = Get-Date
    $formattedStartTime = $StartTime.ToUniversalTime().ToString("HH:mm:ss")
    $BeginMessage = "[$env:COMPUTERNAME-$formattedStartTime" + "z]-[$fn]: Begin Process"    
    #endregion
    
    #'\\FRSCBVIHFX001D\e$\SQL\FRSCBVMBC001P_ArrowECSIberiaProd_FULL_20250317_010513.bak' # Hardcoded backup path

    <## >$DatabaseBackupPath = Get-ChildItem -Path $backupFolder -Filter *.bak |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

    if ($DatabaseBackupPath) {
        Write-Host "Latest .bak file found:"
        Write-Host $DatabaseBackupPath.FullName
    } else {
        Write-Host "No .bak file found in the directory."
    }<##>

    try {
        Push-Location
        Write-Host $BeginMessage
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource "$LogSource" -EventID 1000 -Message "$BeginMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1
        
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

        try {
            # Read the environments topology
            $environment = Get-CurrentEnvironmentConfig
            
            [string]$bcServerInstance = $environment.TargetBCServerInstance
            [string]$dbServer = $environment.DatabaseServerName
            [string]$dbName   = $environment.DatabaseName
            

            Write-EcsRstOutput "DB server name                : $dbServer"
            Write-EcsRstOutput "DB name                       : $dbName"
            Write-EcsRstOutput "Target BC server instance name: $bcServerInstance"
            Write-EcsRstOutput "Env short name                : $global:Restore_EnvShortName"
            Write-EcsRstOutput "Backup file                   : $global:Restore_SQLBackupFile"

            if ([string]::IsNullOrEmpty($global:Restore_SQLBackupFile)) {
                throw "ERROR: SQL backup file has not defined yet"
            }
            Write-EcsRstOutput " "
            
            # Run a SQL backup restore process
            Write-EcsRstOutput ("Running a SQL backup restore process")
            
            Restore-EcsSqlDataDatabaseFromFile -envShortName_arg $global:Restore_EnvShortName -backupFile_arg $global:Restore_SQLBackupFileLocal
            
            Write-EcsRstOutput "SQL backup restore process has been completed successfully"

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
}
<## >
Restore-EcsRstSQLBackup -restorePipelineID_arg 'AAA' #-envShortName_arg 'BCUATCOPY' -SQLServerInstance 'MSSQLSERVER'
<##>