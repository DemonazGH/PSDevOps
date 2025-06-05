function Export-DevUsersAndPerms {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerInstance
    )

    $exportFolder = $global:globalMainPath + "UsersBackup"
    # Ensure the directory exists
    if (-not (Test-Path $exportFolder)) {
        New-Item -ItemType Directory -Path $exportFolder -Force
    }
    $outputFile = "$exportFolder\UsersBackup.csv"
    
    Write-Host "Exporting dev user accounts from BC/NAV server instance '$ServerInstance'..."
    
    # TODO: Implement cloud-based storage for Dev users account names and retrieve them here 
    # to export permissions to file
    
    $devObjects = @('Europe\104573a', 'Europe\104371a')
    
    # Convert each string to a PSCustomObject with property UserName
    $devUsersList = $devObjects | ForEach-Object {
        [PSCustomObject]@{
            UserName = $_
        }
    }
    
    try {
        # Retrieve all users matching the dev environment access list
        $userNameArray = $devUsersList | Select-Object -ExpandProperty UserName
        
        $devUsers = Get-NAVServerUser -ServerInstance $ServerInstance |
            Where-Object { $_.UserName -in $userNameArray}

        #$devUsers = Get-NAVServerUser -ServerInstance $ServerInstance |
        #   Where-Object { $_.UserName -in $devUsersList}

        if (-not $devUsers) {
            Write-Warning "No matches found in environment's users list on '$ServerInstance'."
            return
        }

        Write-Host "Found $($devUsers.Count) dev users. Gathering permission sets..."

        # Build an array to hold user + permission set info
        $exportCollection = @()

        foreach ($user in $devUsers) {
            $permissionSets = Get-NAVServerUserPermissionSet -ServerInstance $ServerInstance `
                                                            -WindowsAccount $user.UserName
            foreach ($perm in $permissionSets) {
                $exportCollection += [PSCustomObject]@{
                    UserName        = $user.UserName
                    UserSecurityId  = $user.UserSecurityID
                    PermissionSetId = $perm.PermissionSetID
                    CompanyName     = $perm.CompanyName
                    FullName        = $user.FullName
                    State           = $user.State
                    LicenseType     = $user.LicenseType
                }
            }
        }

        Write-Host "Exporting to $outputFile..."
        $exportCollection | Export-Csv -Path $outputFile -NoTypeInformation

        Write-Host "Successfully exported dev users & perms to $outputFile"
    }
    catch {
        Write-Error "Error exporting dev users: $_"
    }
    <#
.SYNOPSIS
    Exports all BC/NAV dev user accounts and their permission sets from the 
    specified ServerInstance to a CSV file.

.DESCRIPTION
    This script retrieves the specified users from BC/NAV (using Get-NAVServerUser),
    then for each user, fetches their permission sets (Get-NAVServerUserPermissionSet).
    Finally, it writes the data to a CSV file.

.PARAMETER ServerInstance
    The BC/NAV server instance name, e.g. "BC14_HFX".
#>
}
<## >
Export-DevUsersAndPerms -ServerInstance "BC140_DEV_aka_uat_copy"
<##>