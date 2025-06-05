function Stop-EcsDbcBCInstanceServices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EnvShortName
    )

    # Load environment configuration from Strapi and verify it exists
    $environment = Get-BCEnvironmentConfig -EnvShortName $EnvShortName
    if (-not $environment) {
        Throw "Environment '$EnvShortName' not found in Strapi."
    }

    # List of instance names that fail to stop cleanly
    $failedStops = [System.Collections.Generic.List[string]]::new()

    # If no servers are flagged for restart there is nothing to do
    if ( @($environment.ServersWithServicesToRestart).Count -eq 0 ) {
        Write-Host "There are no servers with services to restart in STRAPI for '$($environment.Name)' environment"
        return
    }
    
    # Iterate over every server that hosts BC services for this environment
    foreach ($srv in $environment.ServersWithServicesToRestart) {
        $serverName      = $srv.ServerName
        $strapiInstances = $srv.services
        
        Write-Host "Validating services on '$serverName'..." -ForegroundColor Cyan
  
        try {
            # Query the remote server for BC instances sharing the target database
            $actualFullNames = Get-ServicesOnServerToHandle -TargetServer $serverName -Environment $environment
        }
        catch {
          Throw "ERROR: Unable to get services on '$serverName': $_"
        }

        # Normalize for comparisonю Extract just the service instance names from the discovered objects
        $actualInstances = $actualFullNames | ForEach-Object  { $_.Service }
        $strapiInstances = $srv.services

        # Fail‐fast drift detection. Abort if the set of services differs from what Strapi reports
        $missingInServer = $strapiInstances | Where-Object { $_ -notin $actualInstances }
        $extraOnServer   = $actualInstances   | Where-Object { $_ -notin $strapiInstances }
        if ($missingInServer.Count -or $extraOnServer.Count) {
            Write-Error "Configuration drift detected on '$serverName'!"

            if ($missingInServer.Count) {
                $errorMsgIn = "In STRAPI but not on server:`n"
                $errorMsgIn += $($missingInServer -join ",`n ")
                Write-Host $errorMsgIn
                Write-Host "----------------------------------"
            }
            if ($extraOnServer.Count) {
                $errorMsgOut += "On server but not in STRAPI:`n"
                $errorMsgOut += $($extraOnServer -join ",`n ")
                Write-Host $errorMsgOut
            }

            Throw "Pipeline aborted - reconcile STRAPI vs. actual services on '$serverName' and re-run. Error message:" + "`n  " +  $errorMsgIn + "`n  " + $errorMsgOut
        }

        # STRAPI config matches the real configuration on the server
        # Stop only those services currently in the 'Running' state
        $instancesToStop = $actualFullNames |
                            Where-Object { $_.Status -eq 'Running' } |
                            ForEach-Object  { $_.Service }

        foreach ($inst in $instancesToStop) {
            $svcName = "MicrosoftDynamicsNavServer`$$inst"
            Write-Host "Stopping '$svcName' on '$serverName'..." -ForegroundColor Yellow

            try {
                $res = Invoke-Command -ComputerName $serverName `
                                      -ArgumentList $svcName `
                                      -ErrorAction Stop -ScriptBlock {
                    param($name)
                    # Check current state of the service on the remote host
                    $svc = Get-Service -Name $name -ErrorAction Stop
                    Write-Output $svc.Status
                    if ($svc.Status -eq 'Stopped') {
                        return @{ Name = $name; Status = 'AlreadyStopped' }
                    }

                    Stop-Service -Name $name -Force -ErrorAction Stop

                    # Poll the service state for up to 30 seconds
                    $timeout = 30; $interval = 2; $elapsed = 0
                    do {
                        Start-Sleep -Seconds $interval
                        $elapsed += $interval
                        $current = (Get-Service -Name $name -ErrorAction SilentlyContinue).Status
                    } while ($current -ne 'Stopped' -and $elapsed -lt $timeout)

                    @{
                        Name   = $name
                        Status = if ($current -eq 'Stopped') { 'Stopped' } else { 'Timeout' }
                    }
                }

                if ($res.Status -in 'Stopped','AlreadyStopped') {
                    Write-Host "-> '$($res.Name)' has $($res.Status) status." -ForegroundColor Green
                }
                else {
                    Write-Warning "-> '$($res.Name)' did not stop in time."
                    $failedStops.Add("$serverName`: $($res.Name) timed out")
                }
            }
            catch {
                Write-Warning "-> Error stopping '$svcName': $_"
                $failedStops.Add("$serverName`: $svcName error")
            }
        }
    }

    # Final check
    # If any services could not be stopped, abort and report them
    if ($failedStops.Count -gt 0) {
        Throw "The following services failed to stop and must be investigated before proceeding with database refresh:`n  " +
              ($failedStops -join ",`n  ")
    }

    Write-Host "All required services (excluding target & unrelated DB-server instances) stopped successfully. Safe to proceed with database refresh." `
               -ForegroundColor Green
    
    return $instancesToStop
}
<## >
Stop-EcsDbcBCInstanceServices -EnvShortName 'NHFX'
<##>
<#
.SYNOPSIS
Stops Business Central server instance services for an environment.

.DESCRIPTION
Given the short name of an environment this function retrieves the
configuration from Strapi, validates that the set of services running on
each server matches that configuration and stops all running instances
that share the target database.  It returns a list of the service
instances that were stopped and throws if any instance fails to stop.
#>