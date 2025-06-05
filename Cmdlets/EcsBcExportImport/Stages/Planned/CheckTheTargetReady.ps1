function CheckTheTargetReady
{
[CmdletBinding()]
param(
            [Parameter(Mandatory=$true)][String] $SOXNumber,
            [ValidateSet("DEV", "UAT", "PRD")]
            [Parameter(Mandatory=$true)][String] $SourceEnvType,
            [ValidateSet("DEV", "UAT", "PRD")]
            [Parameter(Mandatory=$true)][String] $TargetEnvType
    )
try 
{
    $fn = '{0}' -f $MyInvocation.MyCommand
    Write-InitialLogs -fn $fn
    $jsonPath = Get-EnvironmentsConfigJSONFilePath
    $ProdEnvConfig = Get-EnvironmentConfig -EnvironmentType 'PRD' -RelativeFilePath $jsonPath
    $TargetEnvConfig = Get-EnvironmentConfig -EnvironmentType $TargetEnvType -RelativeFilePath $jsonPath
    
    #TODO TRANSFER TO STAGE WHERE STOP/START USED
    # 0) Check if record status ready
    $SoxApprovalObject = Get-SoxApprovalRecordFromTarget -SOXNumber $SOXNumber -ProdEnvConfig $ProdEnvConfig
    $SoxApprovalObjectStatus = $SOXApprovalObject.Status
    if ($SoxApprovalObjectStatus -eq "")
    {
        Write-Error("Sox Change managment record Not Found in  $($ProdEnvConfig.DatabaseName) ")
    }
    if ($SoxApprovalObjectStatus -ne $TargetEnvConfig.StatusCodeToImportObjectsToThisEnv)
    {
        Write-Error("To run the pipeline Sox Change managment record  Rec.Status should be equal to $($TargetEnvConfig.StatusCodeToImportObjectsToThisEnv), current value is:  $SoxApprovalObjectStatus")
    }
}
catch 
{
    $errorMessage = $_
    Write-HostAndLog ("Error: $errorMessage")
    # Register-SOXPipelineStepFailure -ErrorMessageArg $errorMessage -StepArg $fn -VariablesFilePath $VariablesFilePath -TeamsChannelName $TargetEnvType
    Register-SOXPipelineStepFailure -ErrorMessageArg $errorMessage -StepArg $fn -VariablesFilePath $VariablesFilePath -TeamsChannelName $TargetEnvType
throw $errorMessage 
}
finally
{
    Write-LogsToFile -Message $LogBuffer.ToString()
}
}