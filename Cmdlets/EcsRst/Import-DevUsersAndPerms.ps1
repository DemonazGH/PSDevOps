function Import-DevUsersAndPerms {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$ServerInstance
    )
    
    # TODO: Change the file approach to the STRAPI? one. Then delete all $importFile occurances.
    [string]$windowsTempFolder = [environment]::GetEnvironmentVariable("temp","machine")
    [string]$ImportFolder = $windowsTempFolder + "\UsersBackup"
    #$ImportFolder = $global:globalMainPath + "UsersBackup"
    try {
        # Ensure FolderPath exists
        if (-not (Test-Path $ImportFolder)) {
            throw "Folder path '$ImportFolder' not found."
        }

        Write-Host "Looking for the last modified *.csv file in '$ImportFolder'..."
        
        # Get the last modified .sql file
        $importFile = Get-ChildItem -Path $ImportFolder -Filter "*.csv" -File |
                      Sort-Object LastWriteTime -Descending |
                      Select-Object -First 1
    
        if (-not $importFile) {
            throw "File with dev users' accounts info not found in '$ImportFolder'."
        }
    
        $importData = Import-Csv -Path $importFile
        if (-not $importData) {
            Write-Warning "No rows found in $importFile."
            return
        }
    Write-Host "Importing dev user accounts into $ServerInstance from $importFile"
    
    $groupedByUser = $importData | Group-Object -Property UserName
    
    foreach ($group in $groupedByUser) {
        $userName = $group.Name  # The userName value
        $userRows = $group.Group
    
        # 1) Ensure the user exists in BC
        $existingUser = Get-NAVServerUser -ServerInstance $ServerInstance |
            Where-Object { $_.UserName -eq $userName }
    
        if (-not $existingUser) {
            Write-Host "Creating user $userName..."
            # For Windows user:
            New-NAVServerUser -ServerInstance $ServerInstance -WindowsAccount $userName -ErrorAction Stop
            # If you had FullName, State, etc., you'd set them via separate scripts or config.
        }
    
        # 2) Assign each permission set
        foreach ($item in $userRows) {
            Write-Host "Assigning PermissionSet '$($item.PermissionSetId)' to user '$userName' (company '$($item.CompanyName)')..."
            try {
                New-NAVServerUserPermissionSet -ServerInstance $ServerInstance `
                    -WindowsAccount $userName `
                    -PermissionSetId $item.PermissionSetId `
                    -CompanyName $item.CompanyName -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to assign permission set '$permSetId' to '$userName': $_"
            }
        }
    }
    Write-Host "Import completed successfully from $importFile."
    }
    catch {
        Write-Warning "Failed to import dev users' accounts: $_"
    }
    <#
.SYNOPSIS
    Imports BC/NAV dev user accounts and their permission sets from a CSV file 
    (created by Export-DevUsersAndPerms.ps1), to the specified ServerInstance.

.DESCRIPTION
    This script reads the CSV of dev users & perms, ensures each user is created 
    (assuming WindowsAccount), then reassigns each permission set using New-NAVServerUserPermissionSet.

.PARAMETER ServerInstance
    The BC/NAV server instance name, e.g. "BC14_HFX".
#>
}
<## >
Import-DevUsersAndPerms -ServerInstance "BC140_DEV_aka_uat_copy"
<##>