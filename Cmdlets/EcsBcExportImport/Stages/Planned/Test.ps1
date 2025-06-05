function Test
{
    [CmdletBinding()]
    $TargetEnvConfig = Get-BCEnvironmentConfig -envShortName_arg 'N_UAT'
    foreach ($property in $TargetEnvConfig.PSObject.Properties) {
      Write-Output "$($property.Name): $($property.Value)"
  }
    # Write-Host " "
    # Write-Host $TargetEnvConfig
    # Write-Host " "
    # $NewLines = Get-ServicesOnAllServersToHandle -TargetServer 'FRSCBVSQLBC001T.eu.corp.arrow.com' -TargetBCServerInstance NAV_UAT -ComputerName 'FRSCBVSQLBC001T.eu.corp.arrow.com'
    # foreach ($NL in $NewLines)
    # {
    #   Write-Host $NL
    # }
}
