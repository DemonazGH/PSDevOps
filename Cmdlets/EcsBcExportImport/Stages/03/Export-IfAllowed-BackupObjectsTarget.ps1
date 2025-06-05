function Export-IfAllowed-BackupObjectsTarget
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
        Write-Host $VariablesFilePath
        $SOXNumber =  Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "SOXNumber"
        # Write-Host $SOXNumber
        if ($SOXNumber) 
        {
            $SOXArray = ($SOXNumber -split ",") | ForEach-Object { $_.Trim() } 
        }
        $TargetEnvConfig = Get-BCEnvironmentConfig -EnvShortName $TargetEnvType
        $SourceEnvConfig = Get-BCEnvironmentConfig -EnvShortName $SourceEnvType
        $ChangedObjects =  Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ChangedObjects"
        $NavFoldersArray = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "NavFoldersArray"
        # NavFoldersArray
        Write-HostAndLog "Exporting original objects as .txt and .fob as single object files"
        # $LicenseImportRequired = Confirm-LicenseHasBeenChanged -TargetEnvironmentConfiguration $SourceEnvType
        $LicenseImportRequired = Confirm-LicenseHasBeenChanged -TargetEnvironmentConfiguration $TargetEnvConfig
        if ($LicenseImportRequired -eq 'true')
        {
            # Import-BCLicenseToTargetDatabase -TargetEnvironmentConfiguration $TargetEnvConfig
            Import-BCLicenseToTargetDatabase -TargetEnvironmentConfiguration $TargetEnvConfig  
        }
        # Import-BCLicenseToTargetDatabase -TargetEnvironmentConfiguration $TargetEnvConfig  
        Backup-Target-Objects -ChangedObjects $ChangedObjects -NavFoldersArray $NavFoldersArray -SOXArray $SOXArray `
        -TargetEnvironmentConfig  $TargetEnvConfig -SourceEnvironmentConfig $SourceEnvConfig             
    }
    catch {
        $errorMessage = $_
        Write-HostAndLog ("Error: $errorMessage")
        Write-Host $_.Exception.StackTrace
        Register-SOXPipelineStepFailure -ErrorMessageArg $errorMessage -StepArg $fn -VariablesFilePath $VariablesFilePath -TeamsChannelName $TargetEnvType
        throw $errorMessage
    }
    finally {
        Write-LogsToFile -Message $LogBuffer.ToString() -VariablesPath $VariablesFilePath
    }
}

function Backup-Target-Objects {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$ChangedObjects,

        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$NavFoldersArray,

        [Parameter(Mandatory = $true)]
        [array]$SOXArray,

        [Parameter(Mandatory = $true)]
        [array]$TargetEnvironmentConfig,

        [Parameter(Mandatory = $true)]
        [array]$SourceEnvironmentConfig
    )

    [bool]$PreliminaryIsExported = $false
    [bool]$IsExported = $false

    foreach ($n in $SOXArray) 
    {
        $FoldersForThisInstance = $NavFoldersArray | Where-Object { $_.SOXNumber -eq $n } | Select-Object -First 1

        $ChangedObjects | Where-Object { $_.VersionList -like "*$n*" } | ForEach-Object {
            $PreliminaryIsExported = Backup-Target-Object -Force $true `
                -Object $_ `
                -TargetObjectsBackupFolder $FoldersForThisInstance.TargetObjectsBackupFolder `
                -ChangedObjectsSourceFolder $FoldersForThisInstance.ChangedObjectsSourceFolder `
                -IsAnyObjectExported $PreliminaryIsExported `
                -TargetEnvironmentConfig $TargetEnvironmentConfig `
                -SourceEnvironmentConfig $SourceEnvironmentConfig `
                -VersionTag $n `
                -SOXNumberArray $SOXArray

            if (($IsExported -ne $true) -and ($PreliminaryIsExported -eq $true)) {
                $IsExported = $PreliminaryIsExported
            }
        }
    }

    if ($IsExported -eq $false) 
    {
        Write-Error "Nothing to export, quitting"
        return
    }   
}

function Backup-Target-Object(
    [Parameter(Mandatory = $true)]
    [bool]$Force,
    [Parameter(Mandatory = $true)]
    $Object, # The object to process
    [Parameter(Mandatory = $true)]
    [string]$TargetObjectsBackupFolder, # Path to the folder where FOB files are stored or processed
    [Parameter(Mandatory = $true)]
    [string]$ChangedObjectsSourceFolder,  # Path to the folder where TXT files are stored or processed
    [Parameter(Mandatory = $true)]
    [bool]$IsAnyObjectExported,
    [Parameter(Mandatory = $true)]
    [array]$TargetEnvironmentConfig,
    [Parameter(Mandatory = $true)]
    [array]$SourceEnvironmentConfig,
    [Parameter(Mandatory = $true)]
    [string]$VersionTag,
    [Parameter(Mandatory = $true)]
    [array]$SOXNumberArray
    )
{
if (($Object.ID) -eq '')
{
    Write-HostAndLog "This object is dummy. Quitting"
    return
}
$ObjectID = [string]$Object.ID
$ObjectType = [string]$Object.ObjectType
# Write-Host('75 line')
$TypeAsNumber = Text2Type -Text $Object.ObjectType
$ObjectExistsCheckQuery = "SELECT COUNT(*) AS RecordCount FROM [$($TargetEnvironmentConfig.DatabaseName)].[dbo].[Object] WHERE [ID] = '$ObjectID' AND [Version List] LIKE '%$VersionTag%' AND [Type] LIKE '$TypeAsNumber'"
# Write-Host($ObjectExistsCheckQuery)
# Execute the query to check the previous version in Production
$ObjectExistsCheckResult = Invoke-Sqlcmd -Query $ObjectExistsCheckQuery -ServerInstance $TargetEnvironmentConfig.DatabaseServerName
if ($ObjectExistsCheckResult.RecordCount -eq 0)
{
      Write-HostAndLog "Object $($ObjectType) $ObjectID does not exist in target. No backup needed"
      $NewObjectNotNeedBackup = $true
      return $NewObjectNotNeedBackup
}
$FobFile = ($ObjectType) + ($ObjectID) + ".fob"
$TxtFile = ($ObjectType) + ($ObjectID) + ".txt"
$Filter = "Type=" + $TypeAsNumber + "; ID=" + $ObjectID
    # Split the VersionList into individual tags and check if $SOXNumber is present as the latest tag
$VersionTags = $Object.VersionList -split ","
[string]$LastVersionTag = $VersionTags[-1].Trim()
if ($VersionTags.Count -gt 1) 
{
    [string]$PreviousVersionTag = $VersionTags[-2].Trim()
    # ++
    $ConcatenatedString = ""

    foreach ($tag in $VersionTags) 
    {
        $ConcatenatedString += $tag + " "
    }
    # ++
    # Write-HostAndLog "$ObjectID $ConcatenatedString"
    $IsPreviousVersionTagInProduction = Confirm-PreviousVersionBeforeExport -SOXNumber $VersionTag -VersionList $VersionTags -TargetEnvironmentConfig $TargetEnvironmentConfig -ObjectID $ObjectID -ObjectType $TypeAsNumber
    if ($IsPreviousVersionTagInProduction -eq $false)
    {
        throw "Object $($ObjectType) $ObjectID does NOT have $PreviousVersionTag Imported to $($TargetEnvironmentConfig.DatabaseName) , please import it first"
    }
}

if (($LastVersionTag -eq $VersionTag))
{
    Write-HostAndLog "Object $($ObjectType) $ObjectID has $VersionTag as the latest version tag."
    $IsAnyObjectExported = $true
} 
else 
{
    if (-not $LastVersionTag -in $SOXNumberArray)
    {
        throw "Object $($ObjectType) $ObjectID does NOT have $VersionTag as the latest version tag."
    } 
    else {
        $IsAnyObjectExported = $true
    }
}
$FobFile = ($ObjectType) + ($ObjectID) + ".fob"
$TxtFile = ($ObjectType) + ($ObjectID) + ".txt"
$Filter = "Type=" + $ObjectType + "; ID=" + $ObjectID
Write-Host $filter
Write-Host "-DatabaseName $($TargetEnvironmentConfig.DatabaseName) -DatabaseServer $($TargetEnvironmentConfig.DatabaseServerName)"
# FOB File
Export-NAVApplicationObject -DatabaseName $TargetEnvironmentConfig.DatabaseName -DatabaseServer $TargetEnvironmentConfig.DatabaseServerName `
    -Path $TargetObjectsBackupFolder\$FobFile -Filter $Filter -Confirm:$false -Force 
# TXT File
Export-NAVApplicationObject -DatabaseName $TargetEnvironmentConfig.DatabaseName -DatabaseServer $TargetEnvironmentConfig.DatabaseServerName `
    -Path $TargetObjectsBackupFolder\$TxtFile -Filter $Filter -Confirm:$false -Force

return $IsAnyObjectExported
}