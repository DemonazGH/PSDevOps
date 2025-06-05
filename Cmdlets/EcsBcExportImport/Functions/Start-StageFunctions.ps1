function Write-InitialLogs
{
    param (
        [string]$fn
    )
    $global:LogBuffer = New-Object System.Text.StringBuilder 
    Write-HostAndLog '================================================================================================='
    Write-HostAndLog ' '
    $startTime = Get-Date((Get-Date).ToUniversalTime()) -Format HH:mm:ss
    $beginMessage = "[$env:COMPUTERNAME-$startTime" + "z]-[$fn]: Begin Process"
    Write-HostAndLog "$beginMessage"
    Write-HostAndLog '====================='
    # Will write logs to this one below
}