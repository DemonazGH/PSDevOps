function Send-SuccessMessage
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][String] $SourceEnvType,
        [Parameter(Mandatory=$true)][String] $TargetEnvType,
        [Parameter(Mandatory=$false)][String] $VariablesFilePath,
        [Parameter(Mandatory=$false)] [String] $AnyObjectToImport
    )
    try 
    {
        $fn = '{0}' -f $MyInvocation.MyCommand
        Write-InitialLogs -fn $fn
        $global:SOXNumber =  Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "SOXNumber"
        Write-Host "SOXNumber $global:SOXNumber"
        if (-not $VariablesFilePath)
        {
            $VariablesFilePath = $pipelineStagingVariablesFilePath
        }
        Register-SOXPipelineSuccess -VariablesFilePath $VariablesFilePath -TeamsChannelName $TargetEnvType
    }
    catch 
    {
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
