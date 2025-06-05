function Get-ServicesOnServerToHandle {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TargetServer,
        [Parameter(Mandatory=$true)]
        $Environment
    )
    $targetBCServerInstance = $Environment.TargetBCServerInstance
    $computerName = $Environment.TargetBCServerName
    $dbServer = $Environment.DatabaseServerName
    $dbName = $Environment.DatabaseName 
    $s = New-PSSession -ComputerName $computerName
    Write-Host "[$computerName] Get-ServicesOnAllServersToHandle"

    $instanceObjects = Invoke-Command -Session $s -ArgumentList $TargetServer, $targetBCServerInstance, $dbServer, $dbName -ScriptBlock {
        param($TargetServerArg, $TargetBCServerInstanceArg, $dataBaseServer, $dataBaseName )

        Import-Module -name "C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\navadmintool.ps1" -Verbose:$false > $null 
        $Instances = Get-NAVServerInstance
        foreach ($instance in $Instances) 
        {
            if ($instance.ServerInstance -match '\$(.+)$') 
            {
                $Service = $Matches[1]
            }
            else {
                continue
            }
            if ($Service -eq $TargetBCServerInstanceArg) { continue }
            if ($instance.Version -notlike '14*') { continue }
            
            # now fetch its full configuration
            try {
                $cfg = Get-NAVServerConfiguration -ServerInstance $Service -ErrorAction Stop
            }
            catch {
                # instance might not have a proper config – skip it
                continue
            }
            $dbSrvr = ($cfg | Where-Object Key -eq 'DatabaseServer').Value
            $dbNm   = ($cfg | Where-Object Key -eq 'DatabaseName'  ).Value

            # filter by the desired DB server & DB name
            if ($dbSrvr.Split('.')[0] -ne $dataBaseServer.Split('.')[0]) { continue }
            if ($dbNm   -ne $dataBaseName ) { continue }
            [pscustomobject]@{
                Service            = $Service
                Status             = $instance.State
                Version            = $instance.Versions
                DatabaseName       = $dbNm
                Server             = $dbSrvr
            }
        }
    }
    return $instanceObjects
}