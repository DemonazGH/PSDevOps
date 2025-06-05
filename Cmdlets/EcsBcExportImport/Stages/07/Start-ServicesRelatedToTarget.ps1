function Start-ServicesRelatedToTarget
{
    [CmdletBinding()]
    param(
            [Parameter(Mandatory=$true)][String] $SourceEnvType,
            [Parameter(Mandatory=$true)][String] $TargetEnvType,
            [Parameter(Mandatory=$true)][String] $VariablesFilePath
    )
    try 
    {
        $fn = '{0}' -f $MyInvocation.MyCommand
        Write-InitialLogs -fn $fn
        $TargetEnvConfig = Get-BCEnvironmentConfig -EnvShortName $TargetEnvType
        $LicenseImportRequired = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "LicenseImportRequired"
        $ObjectSetIncludesTable = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ObjectSetIncludesTable"
        # $RestartServices = $true  -or ($RestartServices)
        # $tr = $true
        # if ($tr = $true) 
        if (($LicenseImportRequired -eq 'true') -or ($ObjectSetIncludesTable -eq 'true')) 
        {
            # Needed
            $ServicesToRestart = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ServicesToRestart"
            if (-not $ServicesToRestart)
            {
                Write-HostAndLog "No services to gradually restart"
                return
            }
            Write-HostAndLog "Services To Restart" Blue
            foreach ($S in $ServicesToRestart)
            {
                Write-HostAndLog $S
            }
            Start-BCServicesExceptForTarget -TargetEnvConfig $TargetEnvConfig -ServicesToRestart $ServicesToRestart
        }
    }
    catch 
    {
        $errorMessage = $_
        Write-HostAndLog ("Error: $errorMessage")
        Register-SOXPipelineStepFailure -ErrorMessageArg $errorMessage -StepArg $fn -VariablesFilePath $VariablesFilePath -TeamsChannelName $TargetEnvType
        throw $errorMessage
    }
    finally
    {
        Write-LogsToFile -Message $LogBuffer.ToString() -VariablesPath $VariablesFilePath
    }
}