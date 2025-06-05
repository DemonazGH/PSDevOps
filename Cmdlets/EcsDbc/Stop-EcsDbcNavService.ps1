function Stop-EcsDbcNavService {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$ServerInstance
    )

    try {
        Write-Host "Verifying that NAV Server Instance '$ServerInstance' is already stopped..."

        $navInstance = Get-NAVServerInstance -ServerInstance $ServerInstance -ErrorAction Stop
        if ($navInstance.State -eq "Stopped") {
            Write-Host "NAV Server Instance '$ServerInstance' is already stopped. No action required." -ForegroundColor Green
            return
        }

        Write-Host "Stopping NAV Server Instance '$ServerInstance'..."
        Stop-NAVServerInstance -ServerInstance $ServerInstance -Force

        # Wait briefly and confirm status
        Start-Sleep -Seconds 5
        $updatedState = (Get-NAVServerInstance -ServerInstance $ServerInstance).State

        if ($updatedState -eq "Stopped") {
            Write-Host "NAV Server Instance '$ServerInstance' stopped successfully." -ForegroundColor Green
        } else {
            throw "Failed to stop NAV Server Instance '$ServerInstance'. Current state: $updatedState"
        }
    }
    catch {
        Write-Error "Error while stopping NAV Server Instance '$ServerInstance': $_"
        throw
    }
    finally {
        Write-Host "Stop-EcsRstNavService execution completed."
    }
}
