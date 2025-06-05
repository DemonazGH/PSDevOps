function Export-ObjectsFromSource
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
        $SOXNumber =  Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "SOXNumber"
        if ($SOXNumber) 
        {
            $SOXArray = ($SOXNumber -split ",") | ForEach-Object { $_.Trim() } 
        }
        $SourceEnvConfig = Get-BCEnvironmentConfig -EnvShortName $SourceEnvType
        $NavFoldersArray =  Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "NavFoldersArray"
        $ChangedObjects =  Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ChangedObjects"
        # 3) Export original objects from PROD as .txt and .fob as single object files
        $LicenseImportRequired = Confirm-LicenseHasBeenChanged -TargetEnvironmentConfiguration $SourceEnvConfig
        if ($LicenseImportRequired -eq 'true')
        {
            # Import-BCLicenseToTargetDatabase -TargetEnvironmentConfiguration $TargetEnvConfig
            Import-BCLicenseToTargetDatabase -TargetEnvironmentConfiguration $SourceEnvConfig  
        }
        $ExportResult = Export-SourceObjects -Force $true -ChangedObjects $ChangedObjects -SOXArray $SOXArray -NavFoldersArray $NavFoldersArray -SourceEnvironmentConfig $SourceEnvConfig
        Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "FobFile" -NewValue $ExportResult.FobFile               
        Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ObjectSetIncludesTable" -NewValue $ExportResult.ObjectSetIncludesTable   
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
        Write-LogsToFile -Message $LogBuffer.ToString() -VariablesPath $VariablesFilePath
    }
}

function Export-SourceObjects {
    param (
        [Parameter(Mandatory = $true)]
        [bool]$Force,

        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$ChangedObjects,

        [Parameter(Mandatory = $true)]
        [array]$SOXArray,

        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$NavFoldersArray,

        [Parameter(Mandatory = $true)]
        [array]$SourceEnvironmentConfig 
    )
    $ObjectSetIncludesTable = 'false'
    $FobCollection = @()
    [array]$NewSOXArray = @()
    foreach ($n in $SOXArray) {
        $changedObjectsContainVersionTag = $null -ne $ChangedObjects.Where({ $_.VersionList -like "*$n*" }, 'First')
        if ($changedObjectsContainVersionTag)
        {
            $NewSOXArray += $n
        }
        Write-HostAndLog "Exporting each object as .txt and .fob files. Objects:"
        $FoldersForThisInstance = $NavFoldersArray | Where-Object { $_.SOXNumber -eq $n } | Select-Object -First 1

        $ChangedObjects | Where-Object { $_.VersionList -like "*$n*" } | ForEach-Object {
            Export-SourceObject -Force $true -Object $_ `
                -ChangedObjectsSourceFolder $FoldersForThisInstance.ChangedObjectsSourceFolder `
                -SourceEnvironmentConfig $SourceEnvConfig
            Write-HostAndLog "$_"
            if ($ObjectSetIncludesTable -eq 'false' -and $_.ObjectType -eq "table") {
                $ObjectSetIncludesTable = 'true'
                Write-HostAndLog " "
                Write-HostAndLog "[WARNING] Objects to import include table(s), all services sharing the same database will be restarted"
                Write-HostAndLog " "
            }
        }
    }
    if ($changedObjectsContainVersionTag)
        {
            $SOXFileName = $NewSOXArray -join '_'
            Write-HostAndLog "Exporting from DEV: changed objects $SOXFileName as one .fob package"
            # $FilterString = Get-Filter-By-SOXNumber -VersionTag $n
            $FilterString = Get-Filter-By-SOXNumber-Array -SOXArray $NewSOXArray
            Write-Host $FilterString
            Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "FobFilterString" -NewValue $FilterString               
            $FobFile = $SOXFileName + "_" + [DateTime]::Today.ToString("ddMMyyyy") + ".fob"
            $FobFilePath = Join-Path $FoldersForThisInstance.ChangedObjectsSourceFolder $FobFile
            Write-HostAndLog "Filter String $FilterString"
            Export-NAVApplicationObject -DatabaseName $SourceEnvConfig.DatabaseName -DatabaseServer $SourceEnvConfig.DatabaseServerName `
                -Path $FobFilePath -Filter $FilterString -Confirm:$false -Force
            Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "FobFilePath" -NewValue $FobFilePath               
            Write-Host $FobFilePath
        }
        else 
        {
            Write-HostAndLog "Found no object with version tag $SOXFileNam"
        }

    return [PSCustomObject]@{
        FobFile               = $FobFilePath
        ObjectSetIncludesTable = $ObjectSetIncludesTable
    }
}


function Export-SourceObject(
    [Parameter(Mandatory = $true)]
    [bool]$Force,
    [Parameter(Mandatory = $true)]
    $Object, # The object to process
    [Parameter(Mandatory = $true)]
    [string]$ChangedObjectsSourceFolder,  # Path to the folder where TXT files are stored or processed
    [Parameter(Mandatory = $true)]
    [array]$SourceEnvironmentConfig
    )
{
if (($Object.ID) -eq '')
{
    Write-HostAndLog "Current object is dummy. Quitting"
    return
}
$DevTxtFile = ($Object.ObjectType) + ($Object.ID) + ".txt"
$Filter = "Type=" + $Object.ObjectType + "; ID=" + $Object.ID
Export-NAVApplicationObject -DatabaseName $SourceEnvironmentConfig.DatabaseName -DatabaseServer $SourceEnvironmentConfig.DatabaseServerName `
    -Path $ChangedObjectsSourceFolder\$DevTxtFile -Filter $Filter -Confirm:$false -Force 
}