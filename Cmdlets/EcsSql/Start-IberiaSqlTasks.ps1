function Start-IberiaSqlTasks {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] $Environment,
        [Parameter(Mandatory = $true)] [string]$envShortName_arg
    )

    [string]$bcServerInstance = $environment.TargetBCServerInstance
    [string]$dbName = $environment.DatabaseName
    [string]$dbServerName = $environment.DatabaseServerName
    [string]$suffix = "_${envShortName_arg}_$((Get-Date).ToString("ddMMyy"))"
    $companies = Get-NAVCompany -ServerInstance $bcServerInstance

    try {
        # Change dispaly name for environment companies
        Write-Host ("Task: Change dispaly name for environment companies")
        Write-Host ("--------------------------------------------------------")
        # Output company names
        foreach ($company in $companies) {
            [string]$companyName = $company.CompanyName
            Write-Host "Checking company: $companyName"
            $newDisplayName = $companyName + $suffix
           
            # Check if display name was already updated
            $tableName = "[$companyName`$Company Information]"

            # Query current display name
            $queryGetName = "SELECT [Custom System Indicator Text] FROM $tableName"
            try{
                $currentNameResult = Invoke-Sqlcmd -ServerInstance $dbServerName `
                                            -Database $dbName `
                                            -Query $queryGetName -ErrorAction Stop
            }
            catch {
                Write-Warning "Could not retrieve Company Information for '$companyName'. Skipping..."
                continue
            }

            if (-not $currentNameResult -or [string]::IsNullOrWhiteSpace($currentNameResult.Name)) {
                Write-Warning "No display name set for '$companyName'. Proceeding to set it to '$newDisplayName'."
            }
            elseif ($currentNameResult.Name -like "*$suffix") {
                Write-Host "Display name of company '$companyName' was already updated to '$($currentNameResult.Name)'. Skipping..."
                continue
            }

            # Build the query to to change display name in Company Information
            $UpdateQuery = @"
            UPDATE $tableName
            SET [Custom System Indicator Text] = '$newDisplayName'
"@
            Write-Host "Executing update query to change display name in Company Information..."

            try {
                Invoke-Sqlcmd -ServerInstance $dbServerName `
                        -Database $dbName `
                        -Query $UpdateQuery -ErrorAction Stop
            }
            catch {
                Write-Error "Error encountered when executing update query to change display name for companyName: $_"
                throw
            }
            Write-Host "Display name updated to '$newDisplayName' in [$CompanyName\Company Information] table."
        }
        Write-Host "Completing the process of changing display name for environment companies..."
        Write-Host ("========================================================")
        
        # Configure SMTP Mail Setup to prevent emails from being sent
        Write-Host ("========================================================")
        Write-Host ("Task: Set the value of field 50003 in the SMTP Mail Setup (409) table to 'Yes'.")
        Write-Host ("--------------------------------------------------------")
        
        foreach ($company in $companies) {
            $Query = @"
            USE [$dbName];
            UPDATE [$($company.CompanyName)`$SMTP Mail Setup]
                SET [Estamos desarrollando s_n] = 1 
"@
            Write-Host "Executing Query: $Query"
            Invoke-Sqlcmd -ServerInstance $dbServerName -Database $dbName -Query $Query
        }
        Write-Host "Completing the process of setting the value of field 50003 in the SMTP Mail Setup (409) table to 'Yes'..."
        Write-Host ("========================================================")
    }    
    catch {
        Write-Error "An error was encountered while executing Iberia post-restore SQL tasks: $_"
        throw
    }
    finally {
        Write-Host "Iberia-specific post-restore tasks have been successfully completed"
    }
}