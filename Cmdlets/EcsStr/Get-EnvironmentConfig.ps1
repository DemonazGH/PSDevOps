function Get-EnvironmentConfig {
    param (
        [string]$RelativeFilePath,
        [Parameter(Mandatory=$true)]
        # [ValidateSet("DEV", "UAT", "PRD")]
        [string]$EnvironmentType
    )
    $envConfigs = Read-JsonFromFile -RelativeFilePath $RelativeFilePath
    # Filter and retrieve the environment details based on the Name
    $envDetails = $envConfigs | Where-Object { $_.Name -eq $EnvironmentType }
    return $envDetails
}