function Test-ServicesOperational
{
    [CmdletBinding()]
    param(
            # [ValidateSet("DEV", "UAT", "PRD")]
            [Parameter(Mandatory=$true)][String] $SourceEnvType,
            # [ValidateSet("DEV", "UAT", "PRD")]
            [Parameter(Mandatory=$true)][String] $TargetEnvType,
            [Parameter(Mandatory=$true)][String] $VariablesFilePath
    )
    try {
        $fn = '{0}' -f $MyInvocation.MyCommand
        Write-InitialLogs -fn $fn
        # $jsonPath = Get-EnvironmentsConfigJSONFilePath
        $ObjectSetIncludesTable = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ObjectSetIncludesTable"
        Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ServicesNotOperational" -NewValue @{}

        if (-not $ObjectSetIncludesTable)
        {
            Write-HostAndLog "There is no ongoing Sync-NavTenant, because no table change was deployed. Quitting the stage"
            exit
        }
        $TargetEnvConfig = Get-BCEnvironmentConfig -EnvShortName $TargetEnvType
        # $SourceEnvConfig = Get-BCEnvironmentConfig -EnvShortName $SourceEnvType
        # $TargetEnvConfig = Get-EnvironmentConfig -EnvironmentType $TargetEnvType -RelativeFilePath $jsonPath
        # $LicenseImportRequired = Get-EnvironmentConfig -EnvironmentType $TargetEnvType -RelativeFilePath $jsonPath
        $LicenseImportRequired = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "LicenseImportRequired"
        if (($LicenseImportRequired -eq 'true') -or ($ObjectSetIncludesTable -eq 'true')) 
        {
            # $ServersWithServicesToRestart = $TargetEnvConfig.ServersWithServicesToRestart
            $ServicesToCheck = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ServicesToRestart"

            $ServicesToCheck += $TargetEnvConfig.TargetBCServerInstance
            # Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ServicesToRestart" -NewValue $ServicesToRestart
            if (-not $ServicesToCheck)
            {
                Write-HostAndLog "No services to check synch"
                return
            }
            Write-HostAndLog " "
            Write-HostAndLog "The Synch will be checked for the following services" Yellow
            foreach ($S in $ServicesToCheck)
            {
                Write-HostAndLog "$S"
                Write-HostAndLog " "
            }
            $MaxNoOfAttempts = 5
            $TimeBetweenChecks = 60
            $NoOfAttempts = 0
            $result = $false
            $NotOperationalServices = @{}
            # Sync-NAVTenant -ServerInstance 'BC14-Client' -Confirm:$false -Force
            $NoOfAttempts = 0
            $result = $false
            Write-Host "1"
            while (($NoOfAttempts -lt $MaxNoOfAttempts) -and (-not $result)) {
                $NoOfAttempts += 1
                $result = $true  # Assume success unless we detect a failure below
                Write-Host "2"
                foreach ($Server in $TargetEnvConfig.ServersWithServicesToRestart) {   
                    $ServerServices = $Server.Services
                    Write-Host "3"
                    # Services that we're supposed to restart
                    $MatchingServices = $ServerServices | Where-Object { $_ -in $ServicesToCheck }

                    if ($MatchingServices.Count -eq 0) {
                        Write-Host "4"
                        continue  # Nothing to check for this server
                    }

                    # Check service status on this server
                    Write-Host "Services List $ServicesList"
                    $statusOk = ShowServerStatus -ServicesList $MatchingServices -ComputerName $Server.ServerName -VariablesFilePath $VariablesFilePath
                    
                    if (-not $statusOk) {
                        $result = $false  # At least one failure found
                    }
                }

                if (-not $result) {
                    Write-Host "5"
                    Write-HostAndLog "Waiting for the next iteration of NAV service status check. Attempt: $NoOfAttempts"
                    Start-Sleep -Seconds $TimeBetweenChecks
                }
            }

            $ServicesNotOperational = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ServicesNotOperational"
            if ($ServicesNotOperational.Count -gt 0)
            {
                Write-HostAndLog "Services Not Operational:" 
                foreach ($s in $ServicesNotOperational)
                {
                    Write-HostAndLog $s 
                }
            }


            if (-not $result) {
                Write-Error "One or more of the services are not operational after $($MaxNoOfAttempts * $TimeBetweenChecks) seconds. See the logs please"
            }

        }  
    }
    catch {
        $errorMessage = $_
        Write-Host($_)
        Write-HostAndLog "Error: $errorMessage" 
        # Register-SOXPipelineStepFailure -ErrorMessageArg $errorMessage -StepArg $fn -VariablesFilePath $VariablesFilePath -TeamsChannelName $TargetEnvType
        Register-SOXPipelineStepFailure -ErrorMessageArg $errorMessage -StepArg $fn -VariablesFilePath $VariablesFilePath -TeamsChannelName $TargetEnvType
        throw $errorMessage
    }
    finally
    {
        Write-LogsToFile -Message $LogBuffer.ToString() -VariablesPath $VariablesFilePath
    }
} 

function ShowServerStatus {
    param(
    [Parameter(Mandatory=$true)]
    [array] $ServicesList,
    [Parameter(Mandatory=$true)]
    [array] $ComputerName,
    [Parameter(Mandatory=$true)]
    [string] $VariablesFilePath
    )
    $s = New-PSSession -ComputerName $ComputerName

    #$jsonPath = Get-EnvironmentsConfigJSONFilePath
    $ServicesNotOperational = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ServicesNotOperational"
    Invoke-Command -Session $s -ArgumentList $ServicesNotOperational -ScriptBlock {
        param($ServicesNotOperational)
        Import-Module -name "C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\navadmintool.ps1" -Verbose:$false > $null 
        $NoOfGoodServices = 0
        $Serverinstances = Get-NAVServerInstance
        Write-Host "$Serverinstances = Get-NAVServerInstance"
        foreach ($Instance in $Serverinstances) {
            $skip=$false
            if ($Instance.ServerInstance -match '\$(.+)$') 
            {
                $InstanceName = $Matches[1]
            } 
            else 
            {
                $InstanceName = $null
            }
            
            if ($ServicesList -notcontains $InstanceName) 
            {
                $skip = $true
            }
            if ($ServiceState.StartType -eq "Disabled") {$skip=$true}
            if ($instance.Version.Substring(0,2) -ne "14") {$skip=$true}
            if (-not $skip) 
            {
                $locHost = hostname
                $Color="Green"
                if ($instance.State -eq "Running") 
                {
                    $Tenant = get-navtenant $instance.ServerInstance
                    if ($Tenant.State -ne "Operational")
                        {
                            $Color="Red"
                            $ServicesNotOperational += $instance.ServerInstance.PadRight(55)+$instance.State.PadRight(20)
                        }
                    if ($Tenant.State -eq "Operational")
                        {$NoOfGoodServices +=1}
                    
                    $Result=$locHost+" "+$instance.ServerInstance.PadRight(55)+$instance.State.PadRight(20)+$tenant.DatabaseName+"   "+  $Tenant.State
                    Write-Host $Result
                } 
                else
                {
                    $Color="Red"
                    $Result=$locHost+" "+$instance.ServerInstance.PadRight(55)+$instance.State.PadRight(20)
                    Write-Host $Result -color $Color
                    $ServicesNotOperational += $instance.ServerInstance.PadRight(55)+$instance.State.PadRight(20)
                }
            }
        }
        # Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ServicesNotOperational" -NewValue $ServicesNotOperational
        #   return $true
        Write-Host "$NoOfGoodServices - Services List $ServicesList"
        if ($NoOfGoodServices -eq $ServicesList.Count)
        {
            # return $true
            return @($true, $ServicesNotOperational)
        }
        # return $false
        return @($false, $ServicesNotOperational)
    }
    $SetOfServicesIsOperational = $result[0]
    $ServicesNotOperational = $result[1]
    Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ServicesNotOperational" -NewValue $ServicesNotOperational
    return $SetOfServicesIsOperational
}