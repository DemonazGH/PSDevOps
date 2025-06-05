function Start-EcsRstNavService {
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
        
        $environment = Get-CurrentEnvironmentConfig
        [string]$bcServerInstance = $environment.TargetBCServerInstance

        # Starting NAV Server Instance
        Write-EcsRstOutput "Starting BC/NAV Server Instance"
        Write-EcsRstOutput ("========================================================")
        
        $serviceStartedSuccessfully = $false
        try {
            Start-EcsDbcNavService -ServerInstance $bcServerInstance
            $serviceStartedSuccessfully = $true
        }
        catch {
            Write-EcsRstOutput ("ERROR: $_")
            Write-EcsRstOutput ("The process will continue running anyway")
        }
        if ($serviceStartedSuccessfully) {
            Write-EcsRstOutput "BC/NAV Server Instance has been successfully started"
            Write-EcsRstOutput ("========================================================")
        }
        else {
            Write-EcsRstOutput "Failed to start BC/NAV Server Instance. Check logs for more details."
            Write-EcsRstOutput ("========================================================")
        }

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
Start-EcsRstNavService -restorePipelineID_arg 'AAA'
<##>