function Start-SetupCodeunit
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][String] $SourceEnvType,
        [Parameter(Mandatory=$true)][String] $TargetEnvType,
        [Parameter(Mandatory=$false)][String] $SetupCodeunitId
    )
    try 
    {
        $fn = '{0}' -f $MyInvocation.MyCommand
        Write-InitialLogs -fn $fn
        $TargetEnvConfig = Get-BCEnvironmentConfig -EnvShortName $TargetEnvType
        Invoke-NAVCodeunit -ServerInstance $TargetEnvConfig.TargetBCServerInstance -CompanyName $TargetEnvConfig.CompanyNameToOperate -CodeunitId $SetupCodeunitId
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
