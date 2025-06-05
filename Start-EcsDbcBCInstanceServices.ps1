function Start-EcsDbcBCInstanceServices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "Environment short name")]
        [string]$EnvShortName,
        [Parameter(Mandatory = $true, HelpMessage = "Environment short name")]
        $Services,
        [Parameter(Mandatory = $false, HelpMessage = "Number of services to start before pausing")]
        [int]$BatchSize    = 4,
        [Parameter(Mandatory = $false, HelpMessage = "Pause duration (seconds) after each batch")]
        [int]$PauseSeconds = 60
    )

    # Lookup the environment details (servers and instances) from Strapi
    # If the environment cannot be resolved we abort immediately
    $environment = Get-BCEnvironmentConfig $EnvShortName
    if (-not $environment) {
        throw "ERROR: Environment '$EnvShortName' not found."
    }

    # Track any services that fail to start so we can report them at the end
    $failedServices = @()
    # Counter used for simple batching/throttling of start attempts
    $counter = 0

    # Iterate over each server defined for the environment and attempt
    # to start the requested BC services on it
    foreach ($srv in $environment.ServersWithServicesToRestart) {
        $serverName = $srv.ServerName
        Write-Host "Processing server: $serverName" -ForegroundColor Cyan

        # Each BC instance/service defined in the parameter list
        # is processed sequentially for the current server
        foreach ($svc in $Services) {
            # Compose the Windows service name for this BC instance
            $fullServiceName = "MicrosoftDynamicsNavServer`$$svc"
            Write-Host "Attempting to start '$fullServiceName' on '$serverName'..." -ForegroundColor Yellow

            try {
                # Remotely start the service and poll until it is running
                # (all work happens within this script block on the target server)
                $result = Invoke-Command -ComputerName $serverName -ErrorAction Stop -ScriptBlock {
                    param($svcName)

                    # Check if the service exists
                    try {
                        $serviceObj = Get-Service -Name $svcName -ErrorAction Stop
                    }
                    catch {
                        throw "Service '$svcName' not found on this server."
                    }

                    # If the instance is already running simply return
                    if ($serviceObj.Status -eq 'Running') {
                        return @{ Name = $svcName; Status = 'Already Running' }
                    }

                    # Issue the Start-Service command on the remote machine
                    try {
                        Start-Service -Name $svcName -ErrorAction Stop
                    }
                    catch {
                        throw "Failed to send Start-Service to '$svcName': $($_.Exception.Message)"
                    }

                    # Poll the service status until it reports 'Running'
                    # Give up after 60 seconds of waiting
                    $maxWait   = 60
                    $interval  = 5
                    $elapsed   = 0

                    while ($elapsed -lt $maxWait) {
                        $current = (Get-Service -Name $svcName -ErrorAction SilentlyContinue).Status
                        if ($current -eq 'Running') {
                            return @{ Name = $svcName; Status = 'Running' }
                        }
                        Start-Sleep -Seconds $interval
                        # Keep track of the total time waited
                        $elapsed += $interval
                    }

                    # If the service never entered the Running state in time
                    return @{ Name = $svcName; Status = 'Timeout' }
                } -ArgumentList $fullServiceName

                # Inspect result returned by the remote script block
                if ($result.Status -eq 'Running' -or $result.Status -eq 'AlreadyRunning') {
                    Write-Host "Service '$fullServiceName' on '$serverName' is now '$($result.Status)'." -ForegroundColor Green
                }
                else {
                    # Service never reached the Running state
                    Write-Warning "Service '$fullServiceName' on '$serverName' did not reach 'Running' (Status='$($result.Status)')."
                    $failedServices += "'$serverName':$fullServiceName"
                }
            }
            catch {
                # Any Invoke-Command exception lands here
                Write-Warning "Failed to start '$fullServiceName' on '$serverName': $_"
                # Record the problematic instance for later
                $failedServices += "'$serverName': $fullServiceName"
            }

            # Simple throttling to avoid overloading a server with start requests
            $counter++
            if ($counter -ge $BatchSize) {
                Write-Host "Batch of $BatchSize start attempts issued; pausing $PauseSeconds seconds..." -ForegroundColor Cyan
                Start-Sleep -Seconds $PauseSeconds
                $counter = 0
            }
        }
    }

    # Fail the function if any service did not start as expected
    if ($failedServices.Count -gt 0) {
        throw "The following services failed to start (or timed out): $($failedServices -join ', ')"
    }

    # Informational success message once all start attempts succeeded
    Write-Host "All previously stopped BC/NAV services have started successfully." -ForegroundColor Green
}
<## >
Start-EcsDbcBCInstanceServices -EnvShortName 'NHFX'
<##>