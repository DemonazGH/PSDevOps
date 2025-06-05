function Get-ServicesOnServerToHandle {
    # Return information about Business Central services that share
    # the same database as the specified target server
    param (
        [Parameter(Mandatory=$true)]
        [string]$TargetServer,
        [Parameter(Mandatory=$true)]
        $Environment
    )
    # Extract commonly used values from the environment definition
    $targetBCServerInstance = $Environment.TargetBCServerInstance
    $computerName = $Environment.TargetBCServerName
    $dbServer = $Environment.DatabaseServerName
    $dbName = $Environment.DatabaseName
    # Establish a remote session to the server hosting the target instance
    $s = New-PSSession -ComputerName $computerName
    # Inform the operator which server is being queried
    Write-Host "[$computerName] Get-ServicesOnAllServersToHandle"

    # Query the remote computer for NAV/BC service instances
    $instanceObjects = Invoke-Command -Session $s -ArgumentList $TargetServer, $targetBCServerInstance, $dbServer, $dbName -ScriptBlock {
        param($TargetServerArg, $TargetBCServerInstanceArg, $dataBaseServer, $dataBaseName )

        # NAV administration tooling is required for the service queries
        Import-Module -name "C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\navadmintool.ps1" -Verbose:$false > $null
        # Retrieve all service instances on the machine
        $Instances = Get-NAVServerInstance
        foreach ($instance in $Instances)
        {
            # Extract the service name (the text after the "$" in the instance path)
            if ($instance.ServerInstance -match '\$(.+)$')
            {
                $Service = $Matches[1]
            }
            else {
                continue
            }
            # Skip the target instance itself
            if ($Service -eq $TargetBCServerInstanceArg) { continue }
            # Only handle version 14.x services
            if ($instance.Version -notlike '14*') { continue }
            
            # Retrieve full server configuration for further filtering
            try {
                $cfg = Get-NAVServerConfiguration -ServerInstance $Service -ErrorAction Stop
            }
            catch {
                # Instance might not have a proper config – skip it
                continue
            }
            # Grab database server and database name from configuration
            $dbSrvr = ($cfg | Where-Object Key -eq 'DatabaseServer').Value
            $dbNm   = ($cfg | Where-Object Key -eq 'DatabaseName'  ).Value

            # Filter by the desired DB server & DB name
            if ($dbSrvr.Split('.')[0] -ne $dataBaseServer.Split('.')[0]) { continue }
            if ($dbNm   -ne $dataBaseName ) { continue }
            # Return relevant details about the service instance
            [pscustomobject]@{
                Service            = $Service
                Status             = $instance.State
                Version            = $instance.Versions
                DatabaseName       = $dbNm
                Server             = $dbSrvr
            }
        }
    }
    # Return all discovered service instances
    return $instanceObjects
}