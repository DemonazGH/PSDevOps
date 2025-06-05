function New-FoldersForSOX(
    [Parameter(Mandatory = $true)][String] $SOXNumber,
    [Parameter(Mandatory = $true)][String] $SourceEnvironment,
    [Parameter(Mandatory = $true)][String] $TargetEnvironment
    )
{
    Write-Host "Create Folders in New-FoldersForSOX"
    $folderDatePart = (Get-Date).ToString("yyyyMMdd")
    $folderTimePart = (Get-Date).ToString("HHmmss")

    $newFolderPath = Join-Path -Path $globalDevServerRootFolder -ChildPath  $folderDatePart
    $ChildPath = $SourceEnvironment + "-" + $TargetEnvironment +"_" + $folderTimePart
    $newFolderPath = Join-Path -Path $newFolderPath -ChildPath  $ChildPath
    # $global:ThisRunPath = $newFolderPath 
    $newFolderPath = Join-Path -Path $newFolderPath -ChildPath  $SOXNumber 
    # Sub Folders
    $TargetObjectsBackupFolder = $newFolderPath + "\" + $TargetObjectsBackupFolderName
    $ChangedObjectsSourceFolder = $newFolderPath + "\" + $ChangedObjectsFolderName
    # Write to Verbose message stream to allow the use of -Verbose on cmdlets
    Write-HostAndLog "Checking if Folders for original and changed objects exist for SOX Number $SOXNumber."
    # Create Folders
    if (-not (Test-Path -Path $newFolderPath))
    {
        New-Item -ItemType Directory -Path "$newFolderPath"
        Write-HostAndLog "$newFolderPath has been created." -Color 'green'
    }
    if (-not (Test-Path -Path $TargetObjectsBackupFolder))
    {
        New-Item -ItemType Directory -Path "$TargetObjectsBackupFolder"
        Write-HostAndLog "$TargetObjectsBackupFolder has been created." -Color 'green'
    }
    if ((Test-Path -Path $ChangedObjectsSourceFolder) -eq $false)
    {
        New-Item -ItemType Directory -Path $ChangedObjectsSourceFolder
        Write-HostAndLog "$ChangedObjectsSourceFolder has been created." -Color 'green'
    }
    # Output the 2 Folders
    $NavFolders = [PSCustomObject]@{
        SOXNumber = $SOXNumber
        TargetObjectsBackupFolder = ($TargetObjectsBackupFolder)
        ChangedObjectsSourceFolder  = ($ChangedObjectsSourceFolder)
    }
    # Once We have created folders we may store the Log file there
    # Return output
    return $NavFolders
}

function Get-ThisRunPath(
    [Parameter(Mandatory = $true)][string] $SourceEnvironment,
    [Parameter(Mandatory = $true)][string] $TargetEnvironment
) {
    $folderDatePart = (Get-Date).ToString("yyyyMMdd")
    $folderTimePart = (Get-Date).ToString("HHmmss")

    $basePath = Join-Path -Path $globalDevServerRootFolder -ChildPath $folderDatePart
    Write-Host "basepath $basePath"
    $childPath = "$SourceEnvironment-$TargetEnvironment`_$folderTimePart"
    Write-Host "childpath $childPath"
    $thisRunPath = Join-Path -Path $basePath -ChildPath $childPath
    if (-not (Test-Path -Path $thisRunPath))
    {
        New-Item -ItemType Directory -Path "$thisRunPath"
        Write-HostAndLog "$thisRunPath has been created." -Color 'green'
    }
    Write-Host "thisRunPath $thisRunPath"
    
    return $thisRunPath
}


function Get-ChangedObjects {
    param(
        [Parameter(Mandatory = $true)]
        [String] $SOXNumber, 
        [Parameter(Mandatory = $true)]
        [array] $SourceEnvironmentConfig
    )

    Write-HostAndLog "Get Changed Objects containing $SOXNumber in the Version List from the Development Database"
    
    $SqlQuery = "SELECT [Type], [ID], [Name], [Date], [Time], [Version List] FROM [$($SourceEnvironmentConfig.DatabaseName)].[dbo].[Object] WHERE [Type] > 0 AND ([Version List] LIKE '%,$SOXNumber' OR [Version List] LIKE '%, $SOXNumber' OR [Version List] LIKE '$SOXNumber')"
    Write-HostAndLog "Nav server $($SourceEnvironmentConfig.DatabaseServerName)"
    
    $result = Invoke-Sqlcmd -Query $SqlQuery -ServerInstance $($SourceEnvironmentConfig.DatabaseServerName)
    $NavObjects = @()
    if (-not $result)
    {
        Write-HostAndLog "Version tag is not assigned to any of the objects in source"
        return $NavObjects
    }

    foreach ($r in $result) {
        $ObjectType = Type2Text($r[0])
        $ID = $r[1]
        $Name = $r[2]
        $Date = $r[3]
        $Time = $r[4]
        $VersionList = $r[5]

        Write-HostAndLog "Objects to export $Name"

        $NavObject = [PSCustomObject]@{
            ObjectType  = $ObjectType
            ID          = $ID
            Name        = $Name
            Date        = $Date
            Time        = $Time
            VersionList = $VersionList
        }

        $NavObjects += $NavObject
        Write-HostAndLog "Object added to NavObjects"
    }
    Write-HostAndLog "Returning NAV objects"
    return $NavObjects
}

function Confirm-PreviousVersionBeforeExport {
    param (
        [Parameter(Mandatory = $true)]
        [String] $SOXNumber,
        [Parameter(Mandatory = $true)]
        [string[]]$VersionList,
        [Parameter(Mandatory = $true)]
        [array] $TargetEnvironmentConfig,
        [Parameter(Mandatory = $true)]
        [string]$ObjectID,
        [Parameter(Mandatory = $true)]
        [string]$ObjectType
    )
    $SoxIndex = -1
    # Loop through the array and compare each trimmed value with the SOX number
    for ($i = 0; $i -lt $VersionList.Length; $i++) {
        if ($VersionList[$i].Trim() -eq $SOXNumber) {
            $SoxIndex = $i
            break
        }
    }
    # Output the index
    Write-HostAndLog "The index of the SOX number is: $SoxIndex"

    if ($SoxIndex -eq 0) 
    {
        Write-HostAndLog "The index of the SOX number is: $SoxIndex. No previous version to validate." 
        return $true
    }
    if ($SoxIndex -lt 0) 
    {
        Write-Error "The SOXNumber '$SOXNumber' is not found in the Version List of Object ID '$ObjectID'. No previous version to validate." 
        return $false
    }

    # Get the previous version tag
    $PreviousVersionTag = $VersionList[$SoxIndex - 1]

    Write-HostAndLog "Validating previous version '$PreviousVersionTag' for Object ID '$ObjectID' in Target..." -Color 'Blue'

    # Query to check if the previous version tag exists in Production
    $ProdVersionCheckQuery = "SELECT [Version List] FROM [$($TargetEnvironmentConfig.DatabaseName)].[dbo].[Object] WHERE [ID] = '$ObjectID' AND [Version List] LIKE '%$PreviousVersionTag%' AND [Type] LIKE '%$ObjectType%'"

    # Execute the query to check the previous version in Production
    $ProdVersionCheckResult = Invoke-Sqlcmd -Query $ProdVersionCheckQuery -ServerInstance $($TargetEnvironmentConfig.DatabaseServerName)

    if ($ProdVersionCheckResult.Count -eq 0) {
        Write-HostAndLog "The previous version '$PreviousVersionTag' for Object ID '$ObjectID' does not exist in $($TargetEnvironmentConfig.DatabaseServerName). Export halted." -Color 'red'
        return $false
    }

    Write-HostAndLog "Previous version '$PreviousVersionTag' for Object ID '$ObjectID' is present in $($TargetEnvironmentConfig.DatabaseServerName). Proceeding with export." -Color 'green'
    return $true
}