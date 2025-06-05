function Stop-EcsRstBCInstanceServices {
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

        # Read global variables
        Get-EcsRstGlobalVariables

        Write-EcsRstOutput ("********************************************************************************")
        Write-EcsRstOutput ("*** [$fn]")
        Write-EcsRstOutput ("*** Started at : $Start")
        Write-EcsRstOutput ("*** Pipeline ID: $restorePipelineID_arg")
        Write-EcsRstOutput ("*** ----------------------------------------------------------------------------")

        # Check pipeline ID
        if (($null -eq $restorePipelineID_arg) -Or ($restorePipelineID_arg -eq '')) {
            throw "Error: Pipeline ID cannot be empty"
        }
        if ($restorePipelineID_arg -ne $global:Restore_PipelineID) {
            throw "Pipeline ID specified ($restorePipelineID_arg) is different from the pipeline ID used when initializing the restore ($global:Restore_PipelineID). Make sure you run the initialization script at the beginning"
        }
        
        # Stopping BC/NAV Server Instance services
        Write-EcsRstOutput "Stopping BC/NAV Server Instance services"
        Write-EcsRstOutput ("========================================================")
        
        try {
            # Stopping the services and getting the list of stopped services
            $global:Restore_ServicesToRestart = Stop-EcsDbcBCInstanceServices -EnvShortName $global:Restore_EnvShortName
        }
        catch {
            $errorMessage = $_
            # Send the error to the log
            Write-EcsRstOutput ("Error: " + $errorMessage)
            # Register a failed step
            Register-EcsRstStepFailure -errorMessage_arg "$errorMessage" -restoreStep_arg $fn
            
            throw $errorMessage
        }
        
        #Save global variables
        Write-EcsRstGlobalVariables

        Write-Host "$frt"
        Write-EcsRstOutput "BC/NAV Server Instance services have been successfully stopped"
        Write-EcsRstOutput ("========================================================")

        # Show elapsed time
        $elapsedTime = $(get-date) - $StartTime
        $totalTime = "{0:HH:mm:ss.fff}" -f ([datetime]$elapsedTime.Ticks)
        Write-EcsRstOutput (" ")
        Write-EcsRstOutput ('*** Time elapsed: ' + $totalTime.ToString())
        Write-EcsRstOutput ("********************************************************************************")
        Write-EcsRstOutput (" ")
        Write-EcsRstOutput (" ")
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
Stop-EcsRstBCInstanceServices -restorePipelineID_arg 'AAA'
<##>