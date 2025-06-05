function Register-EcsRstSuccessfulRestore {
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
            if ($global:Restore_SkipAllSteps -eq $true) {
                Write-EcsRstOutput ("This step is skipped because some previous step set the mark to skip")
                return
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

            $restoreEndDate = Get-Date
            $restoreEndDate = $restoreEndDate.ToUniversalTime()
            $restoreEndDateStr = $restoreEndDate.ToString('dd.MM.yyyy HH:mm:ss')
            $diff = New-TimeSpan -Start $global:Restore_StartDateTime -End $restoreEndDate
            $diffStr = $diff.ToString('dd\ hh\:mm\:ss')
    
            Write-EcsRstOutput ("Restore started at: $global:Restore_StartStr")
            Write-EcsRstOutput ("Restore ended at  : $restoreEndDateStr")
            Write-EcsRstOutput ("Restore duration  : $diffStr")

            # Deployment duration
            $durationText = "Restore started at (UTC): $global:Restore_StartStr<br>" + 
                            "Restore ended at (UTC)  : $restoreEndDateStr<br>" + 
                            "Restore duration        : $diffStr<br>" + 
                            "Details here (on $global:Restore_EnvShortName)      : $global:Restore_LogFile"

            $restoreInfo =  "SQL backup file used : $global:Restore_SQLBackupFileLocal"

            [string]$caption   = "Successful restore"
            [string]$msgEnv    = "The environment is ready<br><br>" + $restoreInfo
            [string]$msgDevOps = $durationText + "<br><br>" + $restoreInfo
            
            $sqlFileTextBlock = Initialize-EcsTmsTextBlockForAdaptiveCard -Message "SQL backup file used : \$global:Restore_SQLBackupFileLocal" 

            $devBlock = @()
            $devContainer = Initialize-EcsTmsContainerForAdaptiveCard -Title " " -FontSize "Small"
            $devBlock += Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Restore started at (UTC): $global:Restore_StartStr" -Spacing "None";
            $devBlock += Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Restore ended at (UTC)  : $restoreEndDateStr" -Spacing "None";
            $devBlock += Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Restore duration        : $diffStr" -Spacing "None";
            $devBlock += Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Details here (on $global:Restore_EnvShortName)      : $global:Restore_LogFile" -Spacing "None";
            $devBlock += $sqlFileTextBlock
            $devContainer["items"] += $devBlock

            $devMessageColumns = @(
                Initialize-EcsTmsColumnForAdaptiveCard -Width "60px" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Message" -TextWeight "Bolder" )
                Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items $devContainer -Separator $true
            )
            $msgDevOpsCardBody = Initialize-EcsTmsColumnSetForAdaptiveCard -Columns $devMessageColumns -Spacing "None" -Separator $true

            $envBlock = @()
            $envContainer = Initialize-EcsTmsContainerForAdaptiveCard -Title " " -FontSize "Small"
            $envBlock += Initialize-EcsTmsTextBlockForAdaptiveCard -Message "The environment is ready" -Spacing "None"
            $envBlock += $sqlFileTextBlock
            $envContainer["items"] += $envBlock

            $envMessageColumns = @(
                Initialize-EcsTmsColumnForAdaptiveCard -Width "60px" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Message" -TextWeight "Bolder" )
                Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items $envContainer -Separator $true
            )
            
            $msgEnvCardBody = Initialize-EcsTmsColumnSetForAdaptiveCard -Columns $envMessageColumns -Spacing "None" -Separator $true

            # Send message to Teams (DevOps)
            Write-EcsRstOutput ("Sending a success message to the Restores teams channel")
            Send-EcsRstMessageToTeams -messageType_arg "Success" -messageCaption_arg $caption -messageText_arg $msgDevOps -tableItems $msgDevOpsCardBody             

            # Wait for a second 
            Start-Sleep -Seconds 1

            # Send another message to the proper Teams channel
            Write-EcsRstOutput ("Sending a success message to the environment teams channel")
            Send-EcsRstMessageToTeams -messageType_arg "Success" -messageCaption_arg $caption -messageText_arg $msgEnv -teamsChannelName_arg $global:Restore_TeamsChannel -tableItems $msgEnvCardBody

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
    .DESCRIPTION
    .EXAMPLE
    .EXAMPLE
    .LINK
#>

}
<## >
Register-EcsRstSuccessfulRestore -restorePipelineID_arg 'AAA'
<##> 