function Import-EcsRstUserAccessStored {
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

    try {
        Push-Location
        Write-Host $BeginMessage
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource "$LogSource" -EventID 1000 -Message "$BeginMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1
        
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
        
            if (-Not([string]::IsNullOrEmpty($global:Restore_CurrentUserAccessFile))) {
                [bool]$doImport = $false
                if ($global:Restore_KeepBCUserAccess) {
                    Write-EcsRstOutput ("'keepCurrentBCUserAccess' switch was specified. The previous BC user access will be restored")
                    $doImport = $true
                }
                #if ((!$doImport) -And ($environment.KeepUserAccessAfterDataRestore)) {
                #Write-EcsRstOutput ("'KeepUserAccessAfterDataRestore' is turned on in Strapi. The previous AX user access will be restored")
                #$doImport = $true
                #}

                if ($doImport) {
                    if (Test-Path -Path $global:Restore_CurrentUserAccessFile -PathType Leaf) {
                        Write-EcsRstOutput ("Importing BC user access from file: $global:Restore_CurrentUserAccessFile")
                        Import-EcsDbcUserAccess -inputFile_arg $global:Restore_CurrentUserAccessFile -envShortName_arg $global:Restore_EnvShortName
                    }
                    else {
                        throw "ERROR: The current user AX access backup file is not found: $global:Restore_CurrentUserAccessFile"
                    }
                }
                else {
                    Write-EcsRstOutput ("This step will be skipped because nither 'keepCurrentBCUserAccess' switch was specified nor 'KeepUserAccessAfterDataRestore' is turned on in Strapi")
                }
            }
            else {
                Write-EcsRstOutput ("The current user AX access backup has not been taken by the pipeline. This step will be skipped")
            } 
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
    <#
.SYNOPSIS
    Exports all BC/NAV dev user accounts and their permission sets from the 
    specified ServerInstance.

.DESCRIPTION
    This script retrieves the specified users from BC/NAV (using Get-NAVServerUser),
    then for each user, fetches their permission sets (Get-NAVServerUserPermissionSet).
    Finally, it writes the data in JSON format to a pipeline variable.

.PARAMETER ServerInstance
    The BC/NAV server instance name, e.g. "BC14_HFX".
#>
}
<## >
Import-EcsRstUserAccessStored -restorePipelineID_arg 'AAA' -ServerInstance "BC140_DEV_aka_uat_copy"
<##>

