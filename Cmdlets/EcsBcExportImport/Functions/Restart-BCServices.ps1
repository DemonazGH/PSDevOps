# PowerShell Script to Manage NAV Services with Explicit Corrections

# Configuration Variables
$SleepDurationBeforeSwitchingToNextServer = 0.1  # Sleep duration in minutes between iterations
$SleepDurationAfterEachRestartIteration = 1
$MaxServicesToRestartOnOneServerPerOneIteration = 3
$MaxAttemtsToCheckRunningServices = 3
enum EnvironmentType {
    Development
    UAT
    Production
}
function Stop-BCServicesExceptForTarget
{
    param(
        [Parameter(Mandatory=$true)]
        [array]$TargetEnvConfig,
        [Parameter(Mandatory=$true)]
        [string]$VariablesFilePath
    )
    # Initialize an empty array for previously stopped services
    Write-HostAndLog "2" -color 'purple'
    $ServicesToRestart  = @()
    # Stop BC Server Instances and store the stopped service names
    $ServicesToRestart = Stop-BCServerInstances `
        -TargetServer $TargetEnvConfig.DatabaseServerName `
        -TargetBCServerInstance $TargetEnvConfig.TargetBCServerInstance `
        -TargetDB $TargetEnvConfig.DatabaseName `
        -TargetCompany $TargetEnvConfig.CompanyNameToOperate `
        -VariablesFilePath $VariablesFilePath `
        -ServersWithServicesToRestart $TargetEnvConfig.ServersWithServicesToRestart
        Write-HostAndLog "2 END" -color 'purple'
    return $ServicesToRestart
}

function Start-BCServicesExceptForTarget
{
    param(
        [Parameter(Mandatory=$true)]
        [array]$TargetEnvConfig,
        [AllowEmptyCollection()]
        [Parameter(Mandatory=$false)]
        [array]$ServicesToRestart
    )
     Start-GraduallyBCServerInstances `
        -ServicesToRestart $ServicesToRestart `
        -TargetServer $TargetEnvConfig.DatabaseServerName `
        -TargetBCServerInstance $TargetEnvConfig.TargetBCServerInstance `
        -TargetDB $TargetEnvConfig.DatabaseName `
        -TargetCompany $TargetEnvConfig.CompanyNameToOperate `
        -ServersWithServicesToRestart $TargetEnvConfig.ServersWithServicesToRestart
}

function Start-ServiceOnServer {
    param (
        [string]$ServerName,
        [string]$ServiceName
    )
    Start-NAVServerInstance -ServerInstance $BCServerInstanceArg -Force
}

function Import-BCLicenseToTargetDatabase
{
    param(
        [Parameter(Mandatory=$true)]
        [array]$TargetEnvironmentConfiguration
    )
    $LicenseFile = (Resolve-Path -Path $RelativeLicensePath).Path
    Write-HostAndLog "Importing actual license to the BC server instance: $($TargetEnvironmentConfiguration.TargetBCServerInstance)"
    Import-NAVServerLicense -ServerInstance $TargetEnvironmentConfiguration.TargetBCServerInstance -LicenseFile $LicenseFile -Database NavDatabase
}

function Confirm-LicenseHasBeenChanged
{
    param(
        [Parameter(Mandatory=$true)]
        [array]$TargetEnvironmentConfiguration
    )
    $repositoryLicenseDate = Select-String -Path $RelativeLicensePath -Pattern "Oprettet\s*Dato\s*:\s*(.+)"
    if ($repositoryLicenseDate)
    {
        $inputObjectLicenseInfo = Export-NAVServerLicenseInformation -ServerInstance $TargetEnvironmentConfiguration.TargetBCServerInstance
        $currentLicenseDate = Select-String -InputObject $inputObjectLicenseInfo -Pattern "Oprettet\s*Dato\s*:\s*(.+)"
    }
    else 
    {
        Write-HostAndLog "Could not extract license date for comparison with the license in database. Skipping license import."
        return 'false'
    }
    $repositoryLicenseDate = $repositoryLicenseDate.Matches.Groups[1].Value.Trim()
    $currentLicenseDate = $currentLicenseDate.Matches.Groups[1].Value.Trim()
    if ($repositoryLicenseDate -ne $currentLicenseDate) 
    {
        Write-HostAndLog "New license detected. It will be imported to the database."
        return 'true'
    } 
    else 
    {
        Write-HostAndLog "License is up to date. Skipping import."
        return 'false'
    }
}

function Get-SDServerStatusRecordsGTQuery
{  
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetDB,
        [Parameter(Mandatory=$true)]
        [string]$VariablesFilePath
        )
        $ServersWithServicesToRestart = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "TargetEnvConfigServersWithServicesToRestart" 
        if (-not $ServersWithServicesToRestart) 
        {
            Write-Error "No servers found in config. Exiting script Get-SDServerStatusRecordsGTQuery."
            exit
        }
        #ServersWithServicesToRestart
        if ($ServersWithServicesToRestart -contains ',') 
        {
            $ServerList = $ServersWithServicesToRestart -split ','
        }
        else 
        {
            $ServerList = @($ServersWithServicesToRestart)
        }
        if ($ServerList.Count -eq 1) {
            $ServerConditions = "[Server] LIKE '$($ServerList[0])'"
        } 
        else {
            $ServerConditions = ($ServerList | ForEach-Object { "[Server] LIKE '$_'" }) -join " OR "
        }

        # Generate SQL query with correct formatting
        $LinesQuery = 
            "SELECT [Server], [Service], [Path], [Status], [ID]
            FROM [$TargetDB].[dbo].[SD - Server Status Records GT]
            WHERE ($ServerConditions) AND [Service] <> 'Ping' AND [Service] <> ''"
        return $LinesQuery
}

function Get-SDServerSetupGTQuery
{  
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetDB,
        [Parameter(Mandatory=$true)]
        [string]$VariablesFilePath
        )
        $ServersWithServicesToRestart = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "TargetEnvConfigServersWithServicesToRestart" 
        if ($ServersWithServicesToRestart.Count -eq 0) {
            Write-Host "No servers found in config. Exiting script Get-SDServerSetupGTQuery"
            return $HeaderQuery       
        }
        $ServerList = $ServersWithServicesToRestart -split ','
        #ServersWithServicesToRestart
        if ($ServerList.Count -eq 1) {
            $ServerConditions = "[Server Name] LIKE '$($ServerList[0])'"
        } else {
            $ServerConditions = ($ServerList | ForEach-Object { "[Server Name] LIKE '$_'" }) -join " OR "
        }

        # Generate SQL query with correct formatting
        $HeaderQuery = "SELECT [Server Name], [User ID], [Password], [Domain], [Enable]
        FROM [$TargetDB].[dbo].[SD - Server Setup GT] 
        WHERE ($ServerConditions) AND [Enable] = 1 AND [Server Name] <> ''"
        return $HeaderQuery
}


function Stop-BCServerInstances
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetServer,
        [Parameter(Mandatory=$true)]
        [string]$TargetBCServerInstance,
        [Parameter(Mandatory=$true)]
        [string]$TargetDB,
        [Parameter(Mandatory=$true)]
        [string]$TargetCompany,
        [Parameter(Mandatory=$true)]
        [string]$VariablesFilePath,
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$ServersWithServicesToRestart
    )
    Write-HostAndLog "2.1 Start" -color 'purple'
    $Lines = @()
    $Headers = @()
    $ServicesToRestart = @()
    
    Write-Host "Input variables are:"
    Write-Host "$TargetServer"
    Write-Host "$TargetBCServerInstance"
    Write-Host "$TargetDB"
    Write-Host "$TargetCompany"
    Write-Host "$VariablesFilePath"
    Write-Host "$ServersWithServicesToRestart"
    
    foreach ($S in $ServersWithServicesToRestart) {
        # Add to headers
        $Headers += [pscustomobject]@{'Server Name' = $($S.ServerName) }
        # Get service lines from this server
        $NewLines = Get-ServicesOnAllServersToHandle -TargetServer $TargetServer -TargetBCServerInstance $TargetBCServerInstance -ComputerName $S.ServerName
        Write-HostAndLog '--------' -Color 'purple'
        $CurrServicesArr = $S.Services
        Write-HostAndLog "Before Foreach Line"
        foreach ($Line in $NewLines) 
        {
            if ($Line.Service) 
            {
                $Lines += $Line
                $ServiceName = $Line.Service
                $Status = $Line.Status
                $exists = $CurrServicesArr -contains $ServiceName
                Write-HostAndLog "Line: $($Line.Service), $($Line.Status). Does line exist: $exists"
               
        
                if (($Status -eq 'Running') -and ($exists)) {
                    Write-HostAndLog "The Running service added to an array. Service: $ServiceName"

                    Stop-BCServerInstancesPerHeader -Header $S.ServerName -Line $Line `
                    -TargetBCServerInstance $TargetBCServerInstance `
                    -VariablesFilePath $VariablesFilePath `
                    -ServersWithServicesToRestart $ServersWithServicesToRestart
                    $ServicesToRestart += $Line.Service
                }
            }
            Write-HostAndLog "End of lines reached"
        }
    } 
    return $ServicesToRestart
}

function Stop-BCServerInstancesPerHeader  
{
    param (
        [string]$Header,
        [Array]$Line,
        [String]$TargetBCServerInstance,
        [Parameter(Mandatory=$true)]
        [string]$VariablesFilePath,
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$ServersWithServicesToRestart
        )
    if ($ServersWithServicesToRestart.Count -eq 0)
    {
        Write-Error("Servers With Services To Restart array is empty")
    }
    $ServerName = $Header
     Write-Host "Lines $Line | Where-Object { $($_.'PSComputerName') -eq $ServerName }"
        Write-HostAndLog "!!!!"
        $ServiceName = $Line.'Service'
            try {
                Write-HostAndLog "[$ServerName] Before we stop service"
                Write-HostAndLog "-------$ServiceName---------"
                Write-HostAndLog "--------$ServiceName--------"
                Write-HostAndLog "--------$($Line.PSComputerName)--------"
                Write-HostAndLog "Stop-BCServerInstanceOnAServer -BCServerInstance $ServiceName -ComputerName $ServerName"
                Stop-BCServerInstanceOnAServer -BCServerInstance $ServiceName -ComputerName $ServerName
                Write-HostAndLog "-------$ServiceName---------"
                Write-HostAndLog "[$ServerName] Service stopped: $ServiceName"
                
            } 
            catch {
                Write-HostAndLog "[$ServerName] Error: $_"
            }  
}

function Start-GraduallyBCServerInstances
{
    param (
        [Parameter(Mandatory=$false)]
        [AllowEmptyCollection()]
        [array]$ServicesToRestart,
        [Parameter(Mandatory=$true)]
        [string]$TargetServer,
        [Parameter(Mandatory=$true)]
        [string]$TargetBCServerInstance,
        [Parameter(Mandatory=$true)]
        [string]$TargetDB,
        [Parameter(Mandatory=$true)]
        [string]$TargetCompany,
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$ServersWithServicesToRestart
    )

    $TotalStartedServices = 0
    $StartedservicesCounter = 0
    $TotalRunningServices = 0
    $Cycle = 0
    $FailingServices = @()
    $AllServicesStarted = $false

    Write-HostAndLog "Starting the process to gradually restart Business Central services..."

    # Loop through each service to start
    foreach ($ServiceToStart in $ServicesToRestart)
    {
        $matchingServer = $ServersWithServicesToRestart | Where-Object {
            $_.Services -contains $ServiceToStart
        }
        
        if ($matchingServer -and $matchingServer.ServerName)
        {
            Write-HostAndLog "Starting service '$ServiceToStart' on server '$($matchingServer.ServerName)'..."
            Write-HostAndLog "Start-BCServerIntanceOnAServer -BCServerInstance $ServiceToStart -ComputerName $($matchingServer.ServerName)"
            [string]$Serv = $ServiceToStart
            [string]$ComputerName = $matchingServer.ServerName
            Start-BCServerIntanceOnAServer -BCServerInstance $Serv -ComputerName $ComputerName
            Write-HostAndLog "Start-BCServerIntanceOnAServer end"

            $TotalStartedServices += 1
            $StartedservicesCounter +=1  
        }
        else {
            Write-HostAndLog "No matching server found for service '$ServiceToStart'. Skipping..."
        }
        
        if ($StartedServicesCounter -eq $MaxServicesToRestartOnOneServerPerOneIteration)
        {
            Write-HostAndLog "Reached max services to restart on one server. Waiting before switching servers..."
            $StartedServicesCounter = 0
            Start-Sleep -Seconds ($SleepDurationBeforeSwitchingToNextServer * 60)
        }
    }

    Write-HostAndLog "Waiting for services to be up and running..."

    # Check if all services are started and running
    While (-not $AllServicesStarted)
    {
        $TotalRunningServices = 0
        Write-HostAndLog "Checking service status (Cycle $Cycle)..."
    
        foreach ($ServiceToStart in $ServicesToRestart)
        {
            $matchingServer = $ServersWithServicesToRestart | Where-Object {
                $_.Services -contains $ServiceToStart
            }
    
            if ($matchingServer -and $matchingServer.ServerName)
            {
                Write-HostAndLog "Checking if service '$ServiceToStart' on server '$($matchingServer.ServerName)' is running..."
    
                $result = Test-BCServerInstanceIsRunning -BCServerInstance $ServiceToStart -ComputerName $matchingServer.ServerName
    
                if ($result)
                {
                    Write-HostAndLog "Service '$ServiceToStart' on '$($matchingServer.ServerName)' is running."
                    $TotalRunningServices += 1  
                }
                else
                {
                    Write-HostAndLog "Service '$ServiceToStart' on '$($matchingServer.ServerName)' is NOT running."
                    $FailingServices += "[$($matchingServer.ServerName)] $ServiceToStart"
                }
            }
            else
            {
                Write-HostAndLog "Could not find a matching server for service '$ServiceToStart'."
            }
        }
    
        Write-HostAndLog "$TotalRunningServices out of $TotalStartedServices services are currently running."
    
        if ($TotalRunningServices -eq $TotalStartedServices)
        {
            $AllServicesStarted = $true
            Write-HostAndLog "All services have started successfully."
        } 
        else
        {
            $Cycle += 1
            if ($Cycle -lt $MaxAttemtsToCheckRunningServices)
            {
                Write-HostAndLog "Waiting for $SleepDurationBeforeSwitchingToNextServer minutes before next check... (Retry $Cycle of $MaxAttemtsToCheckRunningServices)"
                Start-Sleep -Seconds ($SleepDurationBeforeSwitchingToNextServer * 60)
            }
            else
            {
                Write-HostAndLog "Max retry attempts ($MaxAttemtsToCheckRunningServices) reached. The following services failed to start:" -ForegroundColor Red
                foreach ($S in $FailingServices)
                {
                    Write-HostAndLog "$S" -ForegroundColor Red
                }
                throw 'Unable to run services (listed above)'
            }
        }
    }

    Write-HostAndLog "Proceeding to synchronize the services..."

    $TotalStartedServices = 0
    $StartedservicesCounter = 0

    # Sync services after they are started
    foreach ($ServiceToStart in $ServicesToRestart)
    {
        $matchingServer = $ServersWithServicesToRestart | Where-Object {
            $_.Services -contains $ServiceToStart
        }
        
        if ($matchingServer -and $matchingServer.ServerName)
        {
            Write-HostAndLog "Synchronizing service '$ServiceToStart' on server '$($matchingServer.ServerName)'..."
            Sync-BCServerIntanceOnAServer -BCServerInstance $ServiceToStart -ComputerName $matchingServer.ServerName
            $TotalStartedServices += 1
            $StartedservicesCounter +=1  
        }
        
        if ($StartedServicesCounter -eq $MaxServicesToRestartOnOneServerPerOneIteration)
        {
            Write-HostAndLog "Reached max services to synchronize on one server. Waiting before switching servers..."
            $StartedServicesCounter = 0
            Start-Sleep -Seconds ($SleepDurationBeforeSwitchingToNextServer * 60)
        }
    }

    Write-HostAndLog "Process completed successfully!"
}

function Get-ServicesOnAllServersToHandle
{
    param (
        [Parameter(Mandatory=$true)]
        [string]$TargetServer,
        [Parameter(Mandatory=$true)]
        [string]$TargetBCServerInstance,
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    $ServiceInstances = @{}
    $s = New-PSSession -ComputerName $ComputerName
    Write-HostAndLog "[$ComputerName] Get-ServicesOnAllServersToHandle" Blue
    Invoke-Command -Session $s -ArgumentList $TargetServer, $TargetBCServerInstance -ScriptBlock {
        param($TargetServerArg, $TargetBCServerInstanceArg)

        Import-Module -name "C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\navadmintool.ps1" -Verbose:$false > $null 
        $Instances = Get-NAVServerInstance
        $instanceObjects = foreach ($instance in $Instances) 
        {
            if ($instance.ServerInstance -match '\$(.+)$') 
            {
                $Service = $Matches[1]
            } 
            if ((($Service -ne $TargetBCServerInstanceArg)) -and ($instance.Version -like '14*')) 
            {
                [pscustomobject]@{
                    Service         = $Service
                    Status          = $instance.State
                    Version         = $instance.Version
                    DatabaseName    = $instance.DatabaseName
                    Server          = $instance.DatabaseServer
                }
            }
            Write-Host $instance.Service
        }
        return $instanceObjects
    }
}

function Stop-BCServerInstanceOnAServer {
    param (
        [string]$BCServerInstance,
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    Write-HostAndLog "1 Inside Stop-BCServerInstanceOnAServer"

    $whoami = whoami
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrator")
    Write-Host "Running as: $whoami"
    Write-Host "Admin privileges: $isAdmin"

    Write-HostAndLog "[$ComputerName] Attempting to stop service: $BCServerInstance"
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param($ServiceName)
    
        Write-Output "Running as: $([Environment]::UserName)"
        Write-Output "Admin: $((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))"
    
        $svc = Get-Service -Name "MicrosoftDynamicsNavServer`$$ServiceName" -ErrorAction SilentlyContinue
        if ($null -eq $svc) {
            Write-Output "Service not found: MicrosoftDynamicsNavServer`$$ServiceName"
        }
        else {
            Stop-Service -Name $svc.Name -Force
            Start-Sleep -Seconds 3
            Write-Output "Stopped service: $($svc.Name)"
        }
    } -ArgumentList $BCServerInstance

    Write-HostAndLog "Stopping service $BCServerInstance on server $ComputerName was attempted."
}

function Invoke-RemoteAsAdmin {
    param (
        [string]$ComputerName,
        [string]$Command
    )

    $escapedCommand = $Command.Replace('"', '\"')  # Escape any embedded quotes
    $fullCommand = "powershell -Command `"$escapedCommand`""

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param($cmd)
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -Command `"$cmd`"" -Verb RunAs -WindowStyle Hidden
    } -ArgumentList $escapedCommand
}


function Start-BCServerIntanceOnAServer
{
    param (
        [string]$BCServerInstance,
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    Write-HostAndLog "Start-BCServerIntanceOnAServer"
    $s = New-PSSession -ComputerName $ComputerName
    Invoke-Command -Session $s -ArgumentList $BCServerInstance -ScriptBlock {
        param($BCServerInstanceArg)
        Import-Module -name "C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\navadmintool.ps1" -Verbose:$false > $null
        Start-NAVServerInstance -ServerInstance $BCServerInstanceArg -Force
    }
    Remove-PSSession $s
}

function Sync-BCServerIntanceOnAServer
{
    param (
        [string]$BCServerInstance,
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    $s = New-PSSession -ComputerName $ComputerName
    Invoke-Command -Session $s -ArgumentList $BCServerInstance -ScriptBlock {
        param($BCServerInstanceArg)
        Import-Module -name "C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\navadmintool.ps1" -Verbose:$false > $null
        Sync-NAVTenant -ServerInstance $BCServerInstanceArg -Force
    }
}

function Test-BCServerInstanceIsRunning {
    param (
        [Parameter(Mandatory = $true)]
        [string]$BCServerInstance,

        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    Write-HostAndLog "Start Test-BCServerInstanceIsRunning for $BCServerInstance on $ComputerName"
    $session = New-PSSession -ComputerName $ComputerName

    $isRunning = Invoke-Command -Session $session -ArgumentList $BCServerInstance -ScriptBlock {
        param($BCServerInstanceArg)
        Import-Module -name "C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\navadmintool.ps1" -Verbose:$false > $null
        $service = Get-NAVServerInstance -ServerInstance $BCServerInstanceArg
        if ($service -and $service.State -eq 'Running') {
            return $true
        } else {
            return $false
        }
    }

    Remove-PSSession -Session $session
    Write-HostAndLog "END Test-BCServerInstanceIsRunning for $BCServerInstance on $ComputerName"
    return $isRunning
}

function Get-ServiceDetailsOnASpecificServer {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TargetServer,
        [Parameter(Mandatory = $true)]
        [string]$TargetBCServerInstance
    )

    $Instances = Get-NAVServerInstance
    $instanceObjects = foreach ($instance in $Instances) {
        if ($($instance.ServerInstance) -match '\$(.+)$') 
        {
            $Service = $Matches[1]
        } 
        if ((($instance.DatabaseServer -ne $TargetServer) -or ($Service -ne $TargetBCServerInstance)) -and ($instance.Version -like '14*')) {
            [pscustomobject]@{
                Service         = $Service
                Status          = $instance.State
                Version         = $instance.Version
                DatabaseName    = $instance.DatabaseName
                Server          = $instance.DatabaseServer
            }
        }
    }

    return $instanceObjects
}

function Read-ServerStatus
{
    param(
        [array] $ServicesList
    )
    #$AreAllHandledServersOperational = $true
    if ($ServicesList.Count -eq 0)
    {
        #Write-HostAndLog '================================================================================================='
        Write-HostAndLog '[WARNING] no services to check for status: Operational'
        return
    }
    foreach ($Service in $ServicesList) 
    {
        $instance = Get-NAVServerInstance -ServerInstance $Service
        $ServiceState = Get-Service -Name $instance.ServerInstance
        $AreAllHandledServersOperational = $true
        $skip=$false
        if ($ServiceState.StartType -eq "Disabled") {$skip=$true}
        if ($instance.Version.Substring(0,2) -ne "14") {$skip=$true}
  
        if (-not $skip) 
        {
            $locHost = hostname
            $Color="Green"
            if ($instance.State -eq "Running") 
            {
                $Tenant=  get-navtenant $instance.ServerInstance
                ##[warning]
                if ($Tenant.State -ne "Operational") 
                {
                    $AreAllHandledServersOperational = $false
                    $Color="##[warning]"
                }
                $Result=$locHost+" "+$instance.ServerInstance.PadRight(55)+$instance.State.PadRight(20)+$tenant.DatabaseName+"   "+  $Tenant.State
                Write-HostAndLog  $Result
            } 
            else
            {
                $AreAllHandledServersOperational = $false
                $Color="##[error]"
                $Result=$locHost+" "+$instance.ServerInstance.PadRight(55)+$instance.State.PadRight(20)+$tenant.DatabaseName+"   "+  $Tenant.State
                Write-HostAndLog $Result
            }
            
        }
    } 
    if ($AreAllHandledServersOperational -eq $true)
    {
        #Write-HostAndLog '================================================================================================='
        Write-HostAndLog 'Success: all handled servers state is: Operational'
    } 
    else
    {
        #Write-HostAndLog'================================================================================================='
        Write-Error 'Error: some services status is not operational. See the logs'
    } 
}