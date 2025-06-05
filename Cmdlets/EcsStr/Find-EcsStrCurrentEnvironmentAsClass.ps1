function Find-EcsStrCurrentEnvironmentAsClass {
    [CmdletBinding()]
    Param([Parameter(Mandatory = $true, HelpMessage = "Server name (e.g. FRSCBVBCDO001D)")]
          [string]$serverName_arg
         )
         
    $environment = $null
    foreach ($env in $global:envClassList) {

        $envLocal = $null
        if ($env.DatabaseServerName -eq $serverName_arg) { 
            $envLocal = $env
        }

        $envLocal = $null
        if ($env.TargetBCServerName -eq $serverName_arg) { 
            $envLocal = $env
        }
     
        if ($null -ne $envLocal) {
            if ($null -ne $environment) {
                $s1 = $environment.Name
                $s2 = $envLocal.Name
                throw "ERROR: Server '$serverName_arg' present in more then one environment tolology: '$s1' and '$s2'"
            }
            $environment = $envLocal
        }
    }

    return $environment
}

