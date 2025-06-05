function Start-EcsDbcNavService {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$ServerInstance
    )

    try {
        Write-Host "Verifying that NAV Server Instance '$ServerInstance' is not already running..."

        $navInstance = Get-NAVServerInstance -ServerInstance $ServerInstance -ErrorAction Stop
        if ($navInstance.State -eq "Running") {
            Write-Host "NAV Server Instance '$ServerInstance' is already running. No action required." -ForegroundColor Green
            return
        }

        Write-Host "Starting NAV Server Instance '$ServerInstance'..."
        Start-NAVServerInstance -ServerInstance $ServerInstance -ErrorAction Stop

        # Wait briefly and confirm status
        Start-Sleep -Seconds 5
        $updatedState = (Get-NAVServerInstance -ServerInstance $ServerInstance).State

        if ($updatedState -eq "Running") {
            Write-Host "NAV Server Instance '$ServerInstance' started successfully." -ForegroundColor Green
        } else {
            throw "Failed to start NAV Server Instance '$ServerInstance'. Current state: $updatedState"
        }
    }
    catch {
        Write-Error "Error while starting NAV Server Instance '$ServerInstance': $_"
        throw
    }
    finally {
        Write-Host "Start-EcsRstNavService execution completed."
    }
}
