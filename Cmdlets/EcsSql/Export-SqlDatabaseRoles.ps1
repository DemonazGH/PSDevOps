function Export-SqlDatabaseRoles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Environment
    )
    [string]$dbName = $Environment.DatabaseName
    [string]$dbServerName = $Environment.DatabaseServerName

    $ExportFolder = $global:globalMainPath + "SqlDbRolesBackup"
        # Ensure the tracking directory exists
        if (-not (Test-Path $ExportFolder)) {
            New-Item -ItemType Directory -Path $ExportFolder -Force
        }
        $ExportFilePath = "$ExportFolder\CreateDbRoles.sql"
    
    $query = @"
        USE [$dbName];
        SELECT
            'ALTER ROLE [' + r.name + '] ADD MEMBER [' + m.name + '];' AS CreateRoleMemberStmt
        FROM sys.database_role_members drm
        JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
        JOIN sys.database_principals m ON drm.member_principal_id = m.principal_id
        WHERE r.name IN ('db_owner','public','db_datareader','db_datawriter','db_securityadmin','db_ddladmin')
            AND m.name NOT LIKE '##%'
            AND m.name NOT LIKE 'NT SERVICE%'
            AND m.name NOT IN ('guest');
"@
    try {
        # Run the query
        #$connectionString = "Server=$dbServerName;Database=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True"

        #$results = Invoke-Sqlcmd -ConnectionString $connectionString -Query $query -ErrorAction Stop

        $results = Invoke-Sqlcmd -ServerInstance $dbServerName `
                                -Database $dbName `
                                -Query $query -ErrorAction Stop
        
        if (-not $results) {
            Write-Warning "No roles found for $dbName database. Nothing to export."
        }
        else {
            $roleMembershipLines = $results.CreateRoleMemberStmt
            $roleMembershipLines | Out-File -FilePath $ExportFilePath -Encoding UTF8
            Write-Host "Exported $($roleMembershipLines.Count) role-membership lines to $ExportFilePath"
        }
    }
    catch {
        Write-Error "Failed to export database roles: $_"
    }


}