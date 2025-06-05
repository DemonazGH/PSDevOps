function Stop-ServicesRelatedToTarget
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
        $TargetEnvConfig = Get-BCEnvironmentConfig -EnvShortName $TargetEnvType
        $LicenseImportRequired = Confirm-LicenseHasBeenChanged -TargetEnvironmentConfiguration $TargetEnvConfig
        $ObjectSetIncludesTable = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ObjectSetIncludesTable"
        Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "LicenseImportRequired" -NewValue $LicenseImportRequired
        # $tr = $true
        # if ($tr = $true) 
        if (($LicenseImportRequired -eq 'true') -or ($ObjectSetIncludesTable -eq 'true')) 
        {
            $ServicesToRestart = Stop-BCServicesExceptForTarget -TargetEnvConfig $TargetEnvConfig -VariablesFilePath $VariablesFilePath
            
            Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ServicesToRestart" -NewValue $ServicesToRestart
            if (-not $ServicesToRestart)
            {
                Write-HostAndLog "No services to gradually restart"
                return
            }
            Write-HostAndLog " "
            Write-HostAndLog "[WARNING] Before the pipeline run there were following services with status: Running" Yellow
            Write-HostAndLog "ServicesToRestart $ServicesToRestart"
            Write-HostAndLog " "
        }
        else {
              Write-HostAndLog "No license to import and object set does not include tables"
        }
    }
    catch {
        $errorMessage = $_
        Write-Host($_)
        Write-HostAndLog "Error: $errorMessage" 
        Register-SOXPipelineStepFailure -ErrorMessageArg $errorMessage -StepArg $fn -VariablesFilePath $VariablesFilePath -TeamsChannelName $TargetEnvType
        throw $errorMessage
    }
    finally
    {
        Write-LogsToFile -Message $LogBuffer.ToString() -VariablesPath $VariablesFilePath
    }
} 