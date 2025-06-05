function Get-SoxApprovalRecordFromTarget {
    param (
        [Parameter(Mandatory = $true)]
        [String] $SOXNumber,
        [Parameter(Mandatory = $true)]
        [array]$ProdEnvConfig
    )
    # Define the SQL query to fetch required SOX Approval fields
# Define the SQL query
    $SqlQuery = "SELECT [Unique Change ID], [Status], [Moved To UAT] 
                FROM [$($ProdEnvConfig.DatabaseName)].[dbo].[SOX Approval] 
                WHERE [Unique Change ID] LIKE '%$SOXNumber%'"
    # Log the server being queried
    Write-HostAndLog "Retrieving SOX Approval records from BC server $($ProdEnvConfig.DatabaseServerName)"

    # Execute the SQL query
    $result = Invoke-Sqlcmd -Query $SqlQuery -ServerInstance $($ProdEnvConfig.DatabaseServerName)

    # Process and output each row of the result
    foreach ($r in $result) {
        $MovedToUAT = $r["Moved To UAT"]
        $Status = $r["Status"]
        $UniqueChangeID = $r["Unique Change ID"]

        # Log each object
        Write-HostAndLog "Processing SOX approval record: Unique Change ID - $UniqueChangeID"

        # Create a custom object for better structure
        $SOXApprovalObject = [PSCustomObject]@{
            MovedToUAT    = $MovedToUAT
            Status        = $Status
            UniqueChangeID = $UniqueChangeID
        }

        # Output the custom object
       return $SOXApprovalObject
    }
}

function Update-SoxApprovalRecordInProd {
    param (
        [Parameter(Mandatory = $true)]
        [String] $SoxNumber,
        [Parameter(Mandatory = $true)]
        [String] $NewStatusCode,
        [Parameter(Mandatory = $true)]
        [array]$ProdEnvConfig,
        [Parameter(Mandatory = $true)]
        [array]$UatEnvConfig
    )

    # Inline query to find the status code in the SOX Status GT
    $statusCodeQuery = "SELECT [Code] FROM [$($ProdEnvConfig.DatabaseName)].[dbo].[SOX Status GT] WHERE [Code] = '$NewStatusCode'"
    # Execute the query to get the status code
    $statusCodeResult = Invoke-Sqlcmd -Query $statusCodeQuery -ServerInstance $($ProdEnvConfig.DatabaseServerName)

    if ($statusCodeResult.Count -eq 0) {
        Write-Error "[$($ProdEnvConfig.TargetBCServerInstance)] Status '$NewStatusCode' not found in SOX Status GT." 
        return
    }

    # Get the current user's ID
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $currDate = Convert-ToCustomDateTimeFormat
    # Define update queries based on the status code
    if ($NewStatusCode -eq $ProdEnvConfig.StatusCodeAfterImportObjectsToThisEnv) {
        $updateQuery = "UPDATE [$($ProdEnvConfig.DatabaseName)].[dbo].[SOX Approval] SET [Status] = '$NewStatusCode', [Moved To Production By] = '$currentUser', [Moved To Production Date] = '$currDate' WHERE [Unique Change ID] = '$SoxNumber'"
    } 
    elseif ($NewStatusCode -eq $UatEnvConfig.StatusCodeAfterImportObjectsToThisEnv) {
        $updateQuery = "UPDATE [$($ProdEnvConfig.DatabaseName)].[dbo].[SOX Approval] SET [Status] = '$NewStatusCode', [Moved To UAT] = 1,[Moved To UAT By] = '$currentUser', [Moved To UAT Date] = '$currDate' WHERE [Unique Change ID] = '$SoxNumber'"
    } 
    else {
        Write-Error "Invalid status code '$NewStatusCode'. Only '$($ProdEnvConfig.StatusCodeAfterImportObjectsToThisEnv)' (Production) or '$($UatEnvConfig.StatusCodeAfterImportObjectsToThisEnv)' (UAT) are allowed."
        return
    }

    # Execute the update query
    Invoke-Sqlcmd -Query $updateQuery -ServerInstance $ProdEnvConfig.DatabaseServerName
    Write-HostAndLog "Updated SOX approval record with Unique Change ID '$SoxNumber' to status '$NewStatusCode'. Updated by user $currentUser in production db $($ProdEnvConfig.DatabaseName)."
}
