function Get-BCEnvironmentConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Environment short name")]
        [string]$EnvShortName
    )

    # Read the environments topology
    Get-EcsStrDataAsClass
    
    # Find the environment in the topology
    $environment = $null
    if (!$EnvShortName) {
        Write-Host "Environment short name was not specified. The script will search for it in the environmant topology"
        $serverName = $env:COMPUTERNAME
        Write-Host "Search for the server name in the topology: $serverName"
        $environment = Find-EcsStrCurrentEnvironmentAsClass -serverName_arg $serverName
        if ($null -eq $environment) {
            throw "ERROR: Server was not found in the topology: '$serverName'"
        }
        Write-Host 'Environment found in the topology' -ForegroundColor Blue
        Write-Host $environment.Name '-' $environment.Description
        Write-Host ' '

    }
    else {
        Write-Host "Search for the short name in the topology: $EnvShortName"
        foreach ($env in $global:envClassList) {
            if ($env.Name -eq $EnvShortName.Replace('_','')) {
                $environment = $env
            } 
        }
        if ($null -eq $environment) {
            throw "ERROR: Environment was not found in the topology: '$EnvShortName'"
        }
        Write-Host 'Environment found in the topology' -ForegroundColor Blue
        Write-Host $environment.Name '-' $environment.Description
        Write-Host
    }
    return $environment

}