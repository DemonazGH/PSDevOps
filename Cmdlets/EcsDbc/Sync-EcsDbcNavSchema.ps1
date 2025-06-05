function Sync-EcsDbcNavSchema {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$ServerInstance
    )

    try {
        Write-Host "Starting schema synchronization for '$ServerInstance'..."

        $syncResult = Sync-NAVTenant -ServerInstance $ServerInstance -Mode Sync -Force -ErrorAction Stop
        
        Write-Host "Schema synchronization completed successfully for $ServerInstance."

    }
    catch {
        Write-Error "Sync failed for '$ServerInstance'. Reason: $($_.Exception.Message)"
        throw
    }
    finally {
        Write-Host "Sync-EcsDbcNavSchema execution completed."
    }
}
