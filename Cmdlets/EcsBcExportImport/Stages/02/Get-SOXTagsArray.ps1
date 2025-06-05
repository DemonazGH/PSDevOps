function Get-SOXTagsArray(
    [CmdletBinding()]
    [Parameter(Mandatory = $true)]
    [string] $TargetEnvType
    ) 
{
    try {
        $fn = '{0}' -f $MyInvocation.MyCommand
        Write-InitialLogs -fn $fn
        Write-HostAndLog "Identifying SOX Numbers (Version tags) to process"
        $global:VariablesFilePath = $pipelineStagingVariablesFilePath
        $TargetEnvConfig = Get-BCEnvironmentConfig -EnvShortName $TargetEnvType
        $region = $TargetEnvConfig.Region
        switch ($region) {
            'Nordics' { $regionPrefix = 'N'}
            'Iberia' { $regionPrefix = 'I' }
            Default { $regionPrefix = '' }
        }
        $UATTxt = 'UAT'
        $UATEnvConfig = Get-BCEnvironmentConfig -EnvShortName "$regionPrefix$UATTxt" 
        $SQlQuery = "SELECT [SOX_Number],[Status],[SOX_Status],[DevOps_Status] FROM $DatabasePendingDeploymentObjects WHERE ([Status] LIKE '$($UATEnvConfig.ObjectCodeToImport)')"
        $result = Invoke-Sqlcmd -Query $SqlQuery -ServerInstance $($UATEnvConfig.DatabaseServerName)
        [array]$SOXNumbers = @()
        foreach ($r in $result) 
        {
            $SOXNumbers += $r[0]  # SOX_Number
        }
        $SOXNumbersString = $SOXNumbers -join ','
        Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "SOXNumber" -NewValue $SOXNumbersString
    }
    catch {
        $errorMessage = $_
        Write-HostAndLog ("Error: $errorMessage")
        Register-SOXPipelineStepFailure -ErrorMessageArg $errorMessage -StepArg $fn -VariablesFilePath $VariablesFilePath -TeamsChannelName $TargetEnvType

        throw $errorMessage
    }
    finally {
        Write-LogsToFile -Message $LogBuffer.ToString() -VariablesPath $VariablesFilePath
    }
}
