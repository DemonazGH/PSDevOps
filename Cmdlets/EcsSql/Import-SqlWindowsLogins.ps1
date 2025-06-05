function Import-SqlWindowsLogins {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $dbServerName
    )
    $ImportFolder = $global:globalMainPath + "SQLLoginsBackup"
    try {
        # Ensure FolderPath exists
        if (-not (Test-Path $ImportFolder)) {
            throw "Folder path '$ImportFolder' not found."
        }
    
        Write-Host "Looking for the last modified *.sql file in '$ImportFolder'..."
        
        # Get the last modified .sql file
        $latestFile = Get-ChildItem -Path $ImportFolder -Filter "*.sql" -File |
                      Sort-Object LastWriteTime -Descending |
                      Select-Object -First 1
    
        if (-not $latestFile) {
            throw "No .sql files found in '$ImportFolder'."
        }
    
        Write-Host "Found latest file: $($latestFile.FullName)"
        Write-Host "Importing Windows logins onto '$dbServerName' from '$($latestFile.FullName)'..."
        
        # Instead of -ServerInstance $dbServerName,
        # build a connection string that includes TrustServerCertificate=True
        $DatabaseName = 'TEST-BC-HFX'
        $connectionString = "Server=$dbServerName;Database=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True"

        # Execute the .sql file in the 'master' database
        #Invoke-Sqlcmd -ConnectionString $connectionString `
        #            -InputFile $latestFile.FullName `
        #            -ErrorAction Stop

        # Execute the .sql file in the 'master' database
        #Invoke-Sqlcmd -ServerInstance $dbServerName `
        #              -Database 'master' `
        #              -InputFile $latestFile.FullName `
        #              -ErrorAction Stop
    
        # Build a T-SQL script to sync logins -> database users
        $syncUserScript = @"
        USE [$DatabaseName];
        DECLARE @loginname sysname;
        
        -- We'll iterate over all windows logins relevant to your environment
        DECLARE login_cur CURSOR FOR
        SELECT name
        FROM sys.server_principals
        WHERE type IN ('U','G')
            AND LEFT(name,4) NOT IN ('NT A','NT S')
            AND name NOT LIKE '##%'
            AND name NOT LIKE 'NT SERVICE%';
        
        OPEN login_cur;
        FETCH NEXT FROM login_cur INTO @loginname;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- If user doesn't exist in the DB, create it mapped to the login
            IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = @loginname)
            BEGIN
                DECLARE @sql nvarchar(max) = 'CREATE USER [' + @loginname + '] FOR LOGIN [' + @loginname + ']';
                EXEC (@sql);
                PRINT 'Created user [' + @loginname + '] in [$DatabaseName]';
            END
        
            FETCH NEXT FROM login_cur INTO @loginname;
        END
        
        CLOSE login_cur;
        DEALLOCATE login_cur;
"@
                
        Write-Host "Syncing DB users in [$DatabaseName] with newly imported Windows logins..."

        Invoke-Sqlcmd -ConnectionString $connectionString `
                        -Query $syncUserScript `
                        -ErrorAction Stop

        Write-Host "✅ Database user creation completed for [$DatabaseName]."

        Write-Host "Successfully imported logins from '$($latestFile.Name)' into '$dbServerName'."
    }
    catch {
        Write-Error "Failed to import logins: $_"
        throw
    }

}