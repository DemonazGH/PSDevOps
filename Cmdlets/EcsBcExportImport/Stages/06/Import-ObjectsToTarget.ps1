function Import-ObjectsToTarget
{
    [CmdletBinding()]
    param(
            [Parameter(Mandatory=$true)][String] $SourceEnvType,
            [Parameter(Mandatory=$true)][String] $TargetEnvType,
            [Parameter(Mandatory=$true)][String] $VariablesFilePath
    )
    try {
        $fn = '{0}' -f $MyInvocation.MyCommand
        Write-InitialLogs -fn $fn
        # $SOXNumber =  Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "SOXNumber"
        # if ($SOXNumber) 
        # {
        #     $SOXArray = ($SOXNumber -split ",") | ForEach-Object { $_.Trim() } 
        # }
        $TargetEnvConfig = Get-BCEnvironmentConfig -EnvShortName $TargetEnvType
        $ObjectSetIncludesTable = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ObjectSetIncludesTable"
        $FobFile = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "FobFile"
        # Write-Host $FobFile
        $LicenseImportRequired =  Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "LicenseImportRequired"
        if ($LicenseImportRequired -eq 'true')
        {
            Import-BCLicenseToTargetDatabase -TargetEnvironmentConfiguration $TargetEnvConfig
        }
       Write-HostAndLog "Restarting Target BC Server Instance: $($TargetEnvConfig.TargetBCServerInstance) to discard user connections"
       Restart-NAVServerInstance -ServerInstance $TargetEnvConfig.TargetBCServerInstance
       
        $FobFilterString = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "FobFilterString"
        #    $FobFile = $FobFiles | Where-Object { $_.SOXNumber -eq $n } | Select-Object -First 1
           $FobFilePath = $FobFile
           Import-And-Compile-BCObjects `
           -DatabaseServer $TargetEnvConfig.DatabaseServerName `
           -DatabaseName $TargetEnvConfig.DatabaseName `
           -FobFilePath $FobFilePath `
           -NavServerInstance  $TargetEnvConfig.TargetBCServerInstance `
           -NavServerName $TargetEnvConfig.TargetBCServerName `
           -NavServerManagementPort $TargetEnvConfig.ManagementPort `
           -VersionFilter $FobFilterString `
           -IncludesTableObjects $true
       
      Write-Host "$ObjectSetIncludesTable  $($TargetEnvConfig.TargetBCServerInstance)" 
      Write-HostAndLog "Restarting Target BC Server Instance: $($TargetEnvConfig.TargetBCServerInstance) after compiliation "
      Restart-NAVServerInstance -ServerInstance $TargetEnvConfig.TargetBCServerInstance
      Sync-NAVTenant -ServerInstance $TargetEnvConfig.TargetBCServerInstance -Confirm:$false -Force
        #TODO Importing configuaration package data (BC objects not present in live DEV and UAT)
        # Invoke-NAVCodeunit -ServerInstance $DevEnvConfig.TargetBCServerInstance -CompanyName $DevEnvConfig.CompanyNameToOperate -CodeunitId 8614 -MethodName 'InPipelineExportConfigurationPackagesNoConfirmation' -Argument "$SOXNumber,$FolderPathToStoreConfigPackageFilesIn"
        # Invoke-NAVCodeunit -ServerInstance $UatEnvConfig.TargetBCServerInstance -CompanyName $UatEnvConfig.CompanyNameToOperate -CodeunitId 8614 -MethodName 'ImportPackageXMLFromPathAndApplyPackage' -Argument "$SOXNumber,$FolderPathToStoreConfigPackageFilesIn"
        #TODO Update record later when approved
        #Update-SoxApprovalRecordInProd -SoxNumber $SOXNumber -NewStatusCode $UatEnvConfig.StatusCodeAfterImportObjectsToThisEnv -ProdEnvConfig $ProdEnvConfig -UatEnvConfig $UatEnvConfig      
        #Write-HostAndLog "ObjectSetIncludesTable: $ObjectSetIncludesTable"
    }
    catch {
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

function Import-And-Compile-BCObjects {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DatabaseServer,

        [Parameter(Mandatory = $true)]
        [string]$DatabaseName,

        [Parameter(Mandatory = $true)]
        [string]$FobFilePath,

        [Parameter(Mandatory = $true)]
        [string]$NavServerInstance,

        [Parameter(Mandatory = $true)]
        [string]$NavServerName,

        [Parameter(Mandatory = $true)]
        [int]$NavServerManagementPort,

        [Parameter(Mandatory = $true)]
        [string]$VersionFilter,

        [Parameter(Mandatory = $true)]
        [bool]$IncludesTableObjects
    )

    if ($IncludesTableObjects -eq $true) {
        Cust-Import-NAVApplicationObject `
            -DatabaseServer $DatabaseServer `
            -DatabaseName $DatabaseName `
            -Path $FobFilePath `
            -NavServerInstance $NavServerInstance `
            -NavServerName $NavServerName `
            -ImportAction Overwrite `
            -SynchronizeSchemaChanges Force `
            -NavServerManagementPort $NavServerManagementPort `
            -Confirm:$false `
            -Verbose

        Write-HostAndLog "Objects Imported To Target BC Server Instance: $NavServerInstance with SynchronizeSchemaChanges: Force" -color "Green"
    }
    else {
        Cust-Import-NAVApplicationObject `
            -DatabaseServer $DatabaseServer `
            -DatabaseName $DatabaseName `
            -Path $FobFilePath `
            -NavServerInstance $NavServerInstance `
            -NavServerName $NavServerName `
            -ImportAction Overwrite `
            -SynchronizeSchemaChanges Yes `
            -NavServerManagementPort $NavServerManagementPort `
            -Confirm:$false `
            -Verbose

        Write-HostAndLog "Objects Imported To Target BC Server Instance: $NavServerInstance with SynchronizeSchemaChanges: NowWithValidation" -color "Green"
    }

    $FilterString = $VersionFilter

    Compile-NAVApplicationObject `
        -DatabaseName $DatabaseName `
        -DatabaseServer $DatabaseServer `
        -Filter $FilterString `
        -NavServerInstance $NavServerInstance `
        -NavServerName $NavServerName `
        -NavServerManagementPort $NavServerManagementPort `
        -SynchronizeSchemaChanges Yes
        # -Force  # Uncomment if needed
}
