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

    # Retrieve environment configuration, including ServersWithServicesToRestart
    $environment = Get-BCEnvironmentConfig $EnvShortName
    if (-not $environment) {
        throw "ERROR: Environment '$EnvShortName' not found."
    }

    $failedServices = @()
    $counter = 0

    foreach ($srv in $environment.ServersWithServicesToRestart) {
        $serverName = $srv.ServerName
        Write-Host "Processing server: $serverName" -ForegroundColor Cyan

        foreach ($svc in $Services) {
            $fullServiceName = "MicrosoftDynamicsNavServer`$$svc"
            Write-Host "Attempting to start '$fullServiceName' on '$serverName'..." -ForegroundColor Yellow

            try {
                # All start-and-poll logic is executed remotely via Invoke-Command
                $result = Invoke-Command -ComputerName $serverName -ErrorAction Stop -ScriptBlock {
                    param($svcName)

                    # Check if the service exists
                    try {
                        $serviceObj = Get-Service -Name $svcName -ErrorAction Stop
                    }
                    catch {
                        throw "Service '$svcName' not found on this server."
                    }

                    if ($serviceObj.Status -eq 'Running') {
                        # Already running
                        return @{ Name = $svcName; Status = 'Already Running' }
                    }

                    # Issue Start-Service
                    try {
                        Start-Service -Name $svcName -ErrorAction Stop
                    }
                    catch {
                        throw "Failed to send Start-Service to '$svcName': $($_.Exception.Message)"
                    }

                    # Poll until Running (timeout after 60 seconds)
                    $maxWait   = 60
                    $interval  = 5
                    $elapsed   = 0

                    while ($elapsed -lt $maxWait) {
                        $current = (Get-Service -Name $svcName -ErrorAction SilentlyContinue).Status
                        if ($current -eq 'Running') {
                            return @{ Name = $svcName; Status = 'Running' }
                        }
                        Start-Sleep -Seconds $interval
                        $elapsed += $interval
                    }

                    # If not running by timeout
                    return @{ Name = $svcName; Status = 'Timeout' }
                } -ArgumentList $fullServiceName

                # Inspect result
                if ($result.Status -eq 'Running' -or $result.Status -eq 'AlreadyRunning') {
                    Write-Host "Service '$fullServiceName' on '$serverName' is now '$($result.Status)'." -ForegroundColor Green
                }
                else {
                    Write-Warning "Service '$fullServiceName' on '$serverName' did not reach 'Running' (Status='$($result.Status)')."
                    $failedServices += "'$serverName':$fullServiceName"
                }
            }
            catch {
                # Any Invoke-Command exception lands here
                Write-Warning "Failed to start '$fullServiceName' on '$serverName': $_"
                $failedServices += "'$serverName': $fullServiceName"
            }

            # Batch throttling logic
            $counter++
            if ($counter -ge $BatchSize) {
                Write-Host "Batch of $BatchSize start attempts issued; pausing $PauseSeconds seconds..." -ForegroundColor Cyan
                Start-Sleep -Seconds $PauseSeconds
                $counter = 0
            }
        }
    }

    if ($failedServices.Count -gt 0) {
        throw "The following services failed to start (or timed out): $($failedServices -join ', ')"
    }

    Write-Host "All previously stopped BC/NAV services have started successfully." -ForegroundColor Green
}
<## >
Start-EcsDbcBCInstanceServices -EnvShortName 'NHFX'
<##>