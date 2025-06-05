function Export-SqlWindowsLogins {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $dbServerName
    )

    $ExportFolder = $global:globalMainPath + "SQLLoginsBackup"
        # Ensure the tracking directory exists
        if (-not (Test-Path $ExportFolder)) {
            New-Item -ItemType Directory -Path $ExportFolder -Force
        }
        $ExportFilePath = "$ExportFolder\CreateLogins.sql"
    
    $query = @"
SELECT 'CREATE LOGIN [' + name + '] FROM WINDOWS;' AS CreateStatement
FROM sys.server_principals
WHERE type IN ('U','G')
  AND LEFT(name, 4) NOT IN ('NT A', 'NT S')
"@

    try {
        # Run the query
        $connectionString = "Server=$dbServerName;Database=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True"

        $results = Invoke-Sqlcmd -ConnectionString $connectionString -Query $query -ErrorAction Stop

        #$results = Invoke-Sqlcmd -ServerInstance $dbServerName `
        #                        -Database master `
        #                        -Query $query -ErrorAction Stop
        
        if (-not $results) {
            Write-Warning "No Windows logins found that match the filter. Nothing to export."
        }
        else {
            # Each row has a "CreateStatement" column. Extract and write to file
            $createStatements = $results.CreateStatement
            $createStatements | Out-File -FilePath $ExportFilePath -Encoding UTF8
            
            Write-Host "Exported $($createStatements.Count) CREATE LOGIN statements to $ExportFilePath"
        }
    }
    catch {
        Write-Error "Failed to export Windows logins: $_"
    }
}