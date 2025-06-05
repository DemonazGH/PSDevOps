function Initialize-EcsRstRestoreDataOnlyProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position = 0, HelpMessage = "Unique pipeline id to check that all restore steps use correct initialization variables")]
        [string]$restorePipelineID_arg
       ,[Parameter(Mandatory=$true, Position = 1, HelpMessage = "Short name of the environment to restore")]
        [string]$envShortName_arg
       ,[Parameter(Mandatory=$false, Position = 2, HelpMessage = "Path to a SQL backup file")]
        [string]$sqlBackupFilePath_arg
       ,[Parameter(HelpMessage = "Use the latest Prod modelstore")]
        [switch]$sqlBackupUseLatestProd
       ,[Parameter(HelpMessage = "Keep the current environment BC user access")]
        [switch]$keepCurrentBCUserAccess
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

    try {
        Push-Location
        Write-Host $BeginMessage
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource "$LogSource" -EventID 1000 -Message "$BeginMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1

        ###### Start Script Here 
        $Start = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
        $StartTime = $(get-date)

        # Main variables
        [string]$OutputFolderLocalRoot = $global:globalRstOutputFolderRoot
        
        Write-Host "********************************************************************************" -ForegroundColor Cyan
        Write-Host "*** [$fn]" -ForegroundColor Cyan
        Write-Host "*** Started at                    : $Start" -ForegroundColor Cyan
        Write-Host "*** Host                          : $env:COMPUTERNAME" -ForegroundColor Cyan
        Write-Host "*** Pipeline ID                   : $restorePipelineID_arg" -ForegroundColor Cyan
        Write-Host "*** Env short name                : $envShortName_arg" -ForegroundColor Cyan
        Write-Host "*** SQL backup file path          : $sqlBackupFilePath_arg" -ForegroundColor Cyan
        Write-Host "*** SQL backup - use latest Prod  : $sqlBackupUseLatestProd" -ForegroundColor Cyan
        Write-Host "*** Keep BC user access           : $keepCurrentBCUserAccess" -ForegroundColor Cyan
        Write-Host "********************************************************************************" -ForegroundColor Cyan
        Write-Host ""

        # Check pipeline ID
        if (($null -eq $restorePipelineID_arg) -Or ($restorePipelineID_arg -eq '')) {
            throw "ERROR: Pipeline ID cannot be empty"
        }

        if (([string]::IsNullOrEmpty($sqlBackupFilePath_arg)) -And (!$sqlBackupUseLatestProd)) {
            throw "ERROR: Both sqlBackupFilePath_arg and sqlBackupUseLatestProd parameters cannot be empty"
        }
        if ((-Not([string]::IsNullOrEmpty($sqlBackupFilePath_arg))) -And ($sqlBackupUseLatestProd)) {
            throw "ERROR: Both sqlBackupFilePath_arg and sqlBackupUseLatestProd parameters cannot be filled in"
        }

<## >        # Check that there is no restore pipeline ruuning on the current environment
        [string]$restoreSignFileName = $global:globalRstOutputFolderRoot + "\restoring.txt"
        Write-Host " "
        Write-Host "Checking that there is no restore pipeline ruuning on the current environment"
        Write-Host "Restore sign file local: $restoreSignFileName"
        if (Test-Path -Path $restoreSignFileName -PathType Leaf) {
            Write-Host "A restore process is running because the restore sign file exists '$restoreSignFileName'"
            Write-Host "If you sure that there is no restore pipeline running, delete the file and rerun the pipeline"
            throw "ERROR: Another restore process is currently running on '$envShortName_arg'"
        }
        else {
            Write-Host "There is no restore process running"
        }<##>

        Write-Host " "
        
        # SQL backup file
        [string]$sqlBackupFile = $sqlBackupFilePath_arg
        if ($sqlBackupUseLatestProd) {
            # Grab the latest file in the folder (by name)
            Write-Host "Looking for the latest (by name) file in the Prod backup folder: $global:globalDefaultSQLRestorePath"
            if (Test-Path -Path $global:globalDefaultSQLRestorePath) {
                $File = Get-ChildItem $global:globalDefaultSQLRestorePath -Filter *.bak | Sort-Object Name | Select-Object -Last 1
                if ($File) {
                    $sqlBackupFile = $global:globalDefaultSQLRestorePath + $file
                }
                else {
                    throw "ERROR: Unable to find a SQL backup file in the default path: '$global:globalDefaultSQLRestorePath'"
                }
            }
            else {
                throw "ERROR: Prod backup folder doesn't exist or access denied: $global:globalDefaultSQLRestorePath"
            }
        }
        if ([string]::IsNullOrEmpty($sqlBackupFile)) {
            throw "ERROR: Unable to determine SQL backup file"
        }
        if (-Not(Test-Path -Path $sqlBackupFile -PathType Leaf)) {
            throw "ERROR: SQL backup file doesn't exist: $sqlBackupFile"
        }

        # TODO: Review later
        <## >
        # Read the environments topology
        Write-Host " "
        Write-Host "Read the environments topology"
        Get-EcsStrDataAsClass

        $environment = $null
        Write-Host "Search for the short name in the topology: '$envShortName_arg'"
        foreach ($env in $global:envClassList) {
            if ($env.Name -eq $envShortName_arg) {
                $environment = $env
            } 
        }
        if ($null -eq $environment) {
            throw "ERROR: Environment was not found in the topology: '$envShortName_arg'"
        }
        Write-Host " "

        Write-Host "'LockDataRefresh' property value: $($environment.LockDataRefresh)"
        if ($environment.LockDataRefresh) {
            throw "ERROR: 'LockDataRefresh' property is set for environment '$($environment.Name)'. No data refresh is possible for the environment!"
        } <##>

        Write-Host "---------------------------------"
        Write-Host "Setting global variables"

        $restoreDate = Get-Date
        $restoreTimeLabel = $restoreDate.ToUniversalTime().ToString('yyyyMMddTHHmmssZ')

        $global:Restore_PipelineID             = $restorePipelineID_arg
        $global:Restore_Type                   = $global:globalRstTypeDataOnly
        $global:Restore_EnvShortName           = $envShortName_arg
        $global:Restore_ID                     = $restoreTimeLabel
        $global:Restore_StartDateTime          = $restoreDate
        $global:Restore_StartStr               = $restoreDate.ToUniversalTime().ToString('dd.MM.yyyy HH:mm:ss')
        $global:Restore_OutputFolderLocal      = $OutputFolderLocalRoot + "\" + $global:Restore_ID
        $global:Restore_LogFile                = $global:Restore_OutputFolderLocal + "\" + $global:Restore_ID + ".log"
        $global:Restore_TeamsChannel           = $global:Restore_EnvShortName
        $global:Restore_SQLBackupFile          = $sqlBackupFile
        $global:Restore_SQLBackupFileLocal     = ""
        $global:Restore_KeepBCUserAccess       = ($keepCurrentBCUserAccess -eq $true)
        $global:Restore_SQLReplicationFound    = $false
        $global:Restore_SQLRoleMembershipFile  = ""
        $global:Restore_CurrentUserAccessFile  = ""

        # Hidden global variables
        $global:Restore_SkipAllSteps           = $false
        $global:Restore_SkipNextStep           = $false

        Write-Host "Pipeline ID                   : $global:Restore_PipelineID"
        Write-Host "Env short name to restore     : $global:Restore_EnvShortName"
        Write-Host "Restore ID                    : $global:Restore_ID"
        Write-Host "Started at                    : $global:Restore_StartStr" 
        Write-Host "Output folder local           : $global:Restore_OutputFolderLocal"
        Write-Host "Log file                      : $global:Restore_LogFile"
        Write-Host "Teams channel name            : $global:Restore_TeamsChannel"
        Write-Host "SQL backup file               : $global:Restore_SQLBackupFile"
        Write-Host "Keep BC user access           : $global:Restore_KeepBCUserAccess"
        Write-Host "--------------------------------------------"
        Write-Host ""

        # Create local output folder
        Write-Host "Creating local output folder"
        if (-Not(Test-Path -Path $global:Restore_OutputFolderLocal)) {
            New-Item -Path $global:Restore_OutputFolderLocal -ItemType "directory" -Force | Out-Null
        }
        if (-Not(Test-Path -Path $global:Restore_OutputFolderLocal)) {
            throw "ERROR: Unable to create local output folder: '$global:Restore_OutputFolderLocal'"
        }
        Write-Host "Local output folder has been created: '$global:Restore_OutputFolderLocal'"
        
        # Create log file
        Write-Host "Starting log file, saving restore information"
        Write-EcsRstOutput ("Note: All time in the log is in UTC")
        Write-EcsRstOutput ("********************************************************************************") Cyan
        Write-EcsRstOutput ("*** [$fn]") Cyan
        Write-EcsRstOutput ("*** Pipeline ID                  : $global:Restore_PipelineID") Cyan
        Write-EcsRstOutput ("*** Env short name to restore    : $global:Restore_EnvShortName") Cyan
        Write-EcsRstOutput ("*** Deploy ID                    : $global:Restore_ID") Cyan
        Write-EcsRstOutput ("*** Started at                   : $global:Restore_StartStr") Cyan
        Write-EcsRstOutput ("*** Output folder local          : $global:Restore_OutputFolderLocal") Cyan
        Write-EcsRstOutput ("*** Log file                     : $global:Restore_LogFile") Cyan
        Write-EcsRstOutput ("*** Teams channel name           : $global:Restore_TeamsChannel") Cyan
        Write-EcsRstOutput ("*** SQL backup file              : $global:Restore_SQLBackupFile") Cyan
        Write-EcsRstOutput ("*** Keep BC user access          : $global:Restore_KeepBCUserAccess") Cyan
        Write-EcsRstOutput ("*** ----------------------------------------------------------------------------") Cyan
        Write-EcsRstOutput ("Restore started at $global:Restore_StartStr")

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
Initialize-EcsRstRestoreDataOnlyProcess -restorePipelineID_arg 'AAA' -envShortName_arg 'IHFX' -sqlBackupFilePath_arg "F:\"
<##>