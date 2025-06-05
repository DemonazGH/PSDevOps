function Restart-EcsDbcNavService {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$ServerInstance
    )

    try {
        Write-Host "Restarting NAV Server Instance '$ServerInstance'..."
        
        Restart-NAVServerInstance -ServerInstance $ServerInstance -ErrorAction Stop

        # Wait briefly and confirm status
        Start-Sleep -Seconds 15
        $updatedState = (Get-NAVServerInstance -ServerInstance $ServerInstance).State

        if ($updatedState -eq "Running") {
            Write-Host "NAV Server Instance '$ServerInstance' restarted successfully." -ForegroundColor Green
        } else {
            throw "Failed to restart NAV Server Instance '$ServerInstance'. Current state: $updatedState"
        }
    }
    catch {
        Write-Error "Error while restarting NAV Server Instance '$ServerInstance': $_"
        throw
    }
    finally {
        Write-Host "Restart-EcsRstNavService execution completed."
    }
}
