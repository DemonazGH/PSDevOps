function Find-EcsStrEnvironmentClass {
    [CmdletBinding()]
    Param([Parameter(Mandatory = $true)][string]$envShortName_arg
         )
         
    $environment = $null
    foreach ($env in $global:envClassList) {
        if (($env.Name.Replace('_','') -eq $envShortName_arg) -And ($env.Type -ne "AX")) {
            $environment = $env
        } 
    }

    return $environment
}

