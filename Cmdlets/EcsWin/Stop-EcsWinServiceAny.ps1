function Stop-EcsWinServiceAny {
    [CmdletBinding()]
    param (        
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "ServiceName")]
        [string]$service_arg
       ,[Parameter(Mandatory = $false, Position = 1, HelpMessage = "Local or remote computer name(s)")]
        [string]$computer_arg
       ,[Parameter(Mandatory = $false, Position = 2, HelpMessage = "Prefix for all messages")]
        [string]$msgPrefix_arg
       ,[Parameter(Mandatory = $false, Position = 3, HelpMessage = "Timeout in seconds")]
        [string]$timeOutInSec_arg = 600
       ,[Parameter(HelpMessage = "Disable service before stopping it")]
        [switch]$setDisabled
       ,[Parameter(HelpMessage = "Hide begin-end messages")]
        [switch]$doNotShowWrapperMessages
    )
    #region Standard Start Block
    $Private:Tmr = New-Object System.Diagnostics.Stopwatch; $Private:Tmr.Start()
    $MyParams = $PSBoundParameters | Out-String
    $ErrorActionPreference = "Stop"; $fn = '{0}' -f $MyInvocation.MyCommand
    $LogSource = $fn; $EntryType = "4" #1 Error, 2 Warning, 4 Information
    $StartTime = Get-Date((Get-Date).ToUniversalTime()) -Format HH:mm:ss
    $BeginMessage = "[$env:COMPUTERNAME-$StartTime" + "z]-[$fn]:[$Service]: Begin Process"
    #endregion

    try {
        if (!$doNotShowWrapperMessages) {
            Write-Host $BeginMessage
        }
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource "$LogSource" -EventID 1000 -Message "$BeginMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1

        if (!$computer_arg) { $computer_arg = $env:COMPUTERNAME }

        # Disable service
        if ($setDisabled) {
            Set-Service -Name $service_arg -StartupType Disabled -computername $computer_arg -ErrorAction Stop
        }

        #Stop service
        [System.ServiceProcess.ServiceController]$service = Get-Service -Name $service_arg -ComputerName $computer_arg
        if ($null -eq $service) {
            throw "ERROR: Can't find service '$service_arg' on computer '$computer_arg'"
        }

        $serviceStatus = $service.Status
        Write-Host "$msgPrefix_arg Service '$service_arg' initial status: '$serviceStatus'"

        [int]$waitCount = $timeOutInSec_arg
        do
        {
            $waitCount--
        
            switch($service.Status)
            {
                { @(
                [System.ServiceProcess.ServiceControllerStatus]::ContinuePending,
                [System.ServiceProcess.ServiceControllerStatus]::PausePending,
                [System.ServiceProcess.ServiceControllerStatus]::StartPending,
                [System.ServiceProcess.ServiceControllerStatus]::StopPending) -contains $_ }
                {
                    # A status change is pending. Do nothing.
                    break;
                }
        
                { @(
                [System.ServiceProcess.ServiceControllerStatus]::Paused,
                [System.ServiceProcess.ServiceControllerStatus]::Running) -contains $_ }
                {
                    # The service is paused or running. We need to stop it.
                    Write-Host "$msgPrefix_arg Stopping service '$service_arg' on '$computer_arg'"
                    $service.Stop()
                    break;
                }
        
                { @(
                [System.ServiceProcess.ServiceControllerStatus]::Stopped) -contains $_ }
                {
                    # This is the service state that we want, so do nothing.
                    break;
                }
            }
        
            # Sleep, then refresh the service object.
            Start-Sleep -Seconds 1
            $service.Refresh()

            if (($waitCount % 60) -eq 0) {
                $serviceStatus = $service.Status
                Write-Host "$msgPrefix_arg Service '$service_arg' status: '$serviceStatus'"
            }
        
        } while (($service.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Stopped) -and ($waitCount -gt 0))        

        if ($service.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Stopped) {
            throw "ERROR: Timeout - Unable to stop service '$service_arg' on server '$computer_arg'" # Don't change this message or make the same changes to Stop-EcsDaxAllEnvAOSes catch section
        }
        $serviceStatus = $service.Status
        Write-Host "$msgPrefix_arg Service '$service_arg' final status: '$serviceStatus'"

    }
    catch {
        $er = $_
        Write-PriWinEvent -LogName $globalEventsLog -LogSource $LogSource -EventId 3000 -Message "Failed with:`r`n$er" -EntryType $EntryType; Start-Sleep 1
        Write-Error "[$computerName]-[$fn]: !!! Failed with: `r`n$er!!!!"
    }
    finally {
        $TSecs = [math]::Round(($Private:Tmr.Elapsed).TotalSeconds); $Private:Tmr.Stop(); Remove-Variable Tmr
        #Write-Influx -Measure OperationalTimings -Tags @{Hostname = $env:COMPUTERNAME; Operation = $Fn } -Metrics @{Duration = $Tsecs } -Database deployments -Server $globalInfluxEndpoint
        $EndTime = Get-Date((Get-Date).ToUniversalTime()) -Format HH:mm:ss
        $EndMessage = "[$env:COMPUTERNAME-$EndTime"+"z]-[$fn]:[Elapsed Time: $TSecs seconds]: End Process"
        if (!$doNotShowWrapperMessages) {
            Write-Host $EndMessage
        }
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource "$LogSource" -EventID 2000 -Message "$EndMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1
        Pop-Location
    }
    <#
.SYNOPSIS
.DESCRIPTION
.EXAMPLE
.LINK
#>
}
<## >
Stop-EcsWinServiceAny -service_arg 'AOS60$01' -computer_arg FRSCBVAXHFX301D -setDisabled
<##>