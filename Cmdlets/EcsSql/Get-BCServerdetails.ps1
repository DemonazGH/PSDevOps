    function Get-BCServerdetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$envShortName_arg

    )
	try {
        $JsonPath = Get-EnvironmentsConfigJSONFilePath
        $envConfig = Get-EnvironmentConfig -EnvironmentType 'DEV' -RelativeFilePath $JsonPath        
        Write-Host "*** START OF THE TEST"
        Write-Host $envConfig.Name
        Write-Host $envConfig.Description
        Write-Host $envConfig.DatabaseServerName
        Write-Host "*** END OF THE TEST"
        
        Write-Host "*** Env short name  : $envShortName_arg" -ForegroundColor Cyan
        $serverInstances = Get-NAVServerInstance
        foreach ($instance in $serverInstances) {
            $config = Get-NAVServerConfiguration -ServerInstance $instance.ServerInstance
            $dbName = ($config | Where-Object { $_.Key -eq "DatabaseName" }).Value
            $serverInstance = ($config | Where-Object { $_.Key -eq "ServerInstance" }).Value
            $databaseServer = ($config | Where-Object { $_.Key -eq "DatabaseServer" }).Value
            
            Write-Host "NAV Server Configuration Details:" 
            Write-Host $dbName
            Write-Host $serverInstance
            Write-Host $databaseServer 
        }
	}
    catch {
            Write-Host "Unable to retreive server instance details: $_"
    }
}