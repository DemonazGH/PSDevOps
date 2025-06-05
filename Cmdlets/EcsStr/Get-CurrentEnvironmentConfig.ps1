function Get-CurrentEnvironmentConfig {
    [CmdletBinding()]
    Param([Parameter(Mandatory = $false, HelpMessage = "Server name (e.g. FRSCBVAXSRE302D)")]
          [string]$serverName_arg = $env:COMPUTERNAME
         )

    # Get list of all environments
    $environmentsFile = $global:LiveBCServerConfig
    if (-Not(Test-Path -Path "$environmentsFile" -PathType Leaf)) {
        throw "ERROR: BC environments file not found: '$environmentsFile'"
    }

    Write-Host " "
    Write-Host "Current environmet is $serverName_arg"
    Write-Host "Reading BC environments configuration..."
    $envBCList = Get-Content $environmentsFile | ConvertFrom-Json
    Write-Host "Environments found: $($envBCList.Count)"

    $environment = $null
    foreach ($env in $envBCList) {

        $envLocal = $null
        if ($env.DatabaseServerName -like "*$serverName_arg*") { 
            $envLocal = $env
        }
        if ($env.TargetBCServerName -like "*$serverName_arg*") { 
            $envLocal = $env
        }
        #if ($env.ServersWithServicesToRestart -contains $serverName_arg) { 
        #    $envLocal = $env
        #}

        # Ensure we don't detect multiple environments for the same server
        if ($null -ne $envLocal) {
            if ($null -ne $environment) {
                $s1 = $environment.Name
                $s2 = $envLocal.Name
                throw "ERROR: Server '$serverName_arg' is present in multiple environments: '$s1' and '$s2'"
            }
            $environment = $envLocal
        }
    }

    if ($null -ne $environment) {
        Write-Host "Environment found: $($environment.Name) - $($environment.Description)"
    }
    else {
        throw "ERROR: No matching BC environment found for server: '$serverName_arg'"
    }
    Write-Host " "

    return $environment
}
<## >
Get-CurrentEnvironmentConfig
<##>