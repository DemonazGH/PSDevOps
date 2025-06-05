function Get-SourceObjectsDataAndPrepareFolders
{
    [CmdletBinding()]
    param(
            [Parameter(Mandatory=$true)][String] $SourceEnvType,
            [Parameter(Mandatory=$true)][String] $TargetEnvType
    )
    try {
        $fn = '{0}' -f $MyInvocation.MyCommand
        Write-InitialLogs -fn $fn

        $VariablesFilePath = $pipelineStagingVariablesFilePath
        $SOXNumber = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "SOXNumber"
        Write-Host $SOXNumber
        $SOXArray = $SOXNumber -split ','
        $TargetEnvConfig = Get-BCEnvironmentConfig -EnvShortName $TargetEnvType
        $SourceEnvConfig = Get-BCEnvironmentConfig -EnvShortName $SourceEnvType
        Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "TargetEnvConfigServersWithServicesToRestart" -NewValue $TargetEnvConfig.ServersWithServicesToRestart

        Write-HostAndLog "Prepare Implementation of SOX Number $SOXNumber"

        $ValidatedSOXArray = @()
        $ChangedObjects = @()

        foreach ($n in $SOXArray) 
        {
            $newObjects = Get-ChangedObjects -SOXNumber $n -SourceEnvironmentConfig $SourceEnvConfig -Verbose

            if ($newObjects) 
            {
                $shouldInclude = $false
                Write-Host('New objects not empty')
                foreach ($o in $newObjects) {
                    $ObjectID = [string]$o.ID
                    $ObjectType = Text2Type -Text $o.ObjectType
                    Write-Host('looping Foreach object in new objects')
                    Write-Host $SqlQuery
                    $SqlQuery = "SELECT [ID], [Date], [Time], [Type] FROM [$($TargetEnvConfig.DatabaseName)].[dbo].[Object] WHERE [ID] = '$ObjectID'"
                    # Execute the query
                    $result1 = Invoke-Sqlcmd -Query $SqlQuery -ServerInstance $TargetEnvConfig.DatabaseServerName
                    # Initialize a collection to store matching rows
                    $filteredResults = @()
                    
                    Write-Host "Not Filtered Result Count $($result1.Count)"
                    # Loop through and filter
                    foreach ($r in $result1) 
                    {
                        if (($r.Type -eq $ObjectType) -and ($r.ID -eq $o.ID))
                        {
                            $filteredResults += $r
                        }
                        Write-Host "($($r.Type) -eq $ObjectType) -and ($($r.ID) -eq $($o.ID))"
                    }

                    # Optional: log results
                    foreach ($r in $filteredResults) 
                    {
                        Write-Host "Date: $($r.Date), Time: $($r.Time), Type: $($r.Type)"
                    }
                    $result = $filteredResults
                    # Write-Host $ObjectType
                    # $SqlQuery = "SELECT [Date], [Time], [Type] FROM [$($TargetEnvConfig.DatabaseName)].[dbo].[Object] WHERE [ID] = '$ObjectID' AND [Type] LIKE '%$ObjectType%'"
                    # $result = Invoke-Sqlcmd -Query $SqlQuery -ServerInstance $TargetEnvConfig.DatabaseServerName
                    Write-Host "Result Count $($result.Count)"
                    if ($result.Count -eq 1) {
                        Write-Host('Result not empty')
                        $targetDate = Get-Date $result[0].Date
                        $targetTime =  $result[0].Time
                        $sourceDate = Get-Date $o.Date
                        $sourceTime = $o.Time
                        Write-HostAndLog "Target DateTime $targetDate $targetTime , Source DateTime $sourceDate $sourceTime"
                        if ($targetDate -ne $sourceDate -or $targetTime -ne $sourceTime) 
                        {
                            Write-HostAndLog "shouldInclude $n $targetDate -ne $sourceDate -or $targetTime -ne $sourceTime "
                            $shouldInclude = $true
                            break
                        }
                    } 
                    else 
                    {
                        Write-Host('Result empty')
                        # If object not found or more than one row returned, consider changed
                        $shouldInclude = $false
                        break
                    }
                }
                if ($shouldInclude) {
                    $ChangedObjects += $newObjects
                    $ValidatedSOXArray += $n
                } 
                else {
                    Write-HostAndLog "All objects under $n are identical. Skipping."
                }
            }
            else 
            {
                Write-HostAndLog "There are no objects tagged with the version tag $n"
            }
        }
        if ($ChangedObjects)
        {
            Write-HostAndLog "Objects collected"
            Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "AnyObjectsToImport" -NewValue $true
        }
        else 
        {
            Write-HostAndLog("There are no objects tagged with the version tag $SOXNumber")
            Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "AnyObjectsToImport" -NewValue $false
        }

        $SOXNumbersString = $ValidatedSOXArray -join ','
        if ($SOXNumbersString)
        {
            Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "SOXNumber" -NewValue $SOXNumbersString
        }
        $SkippedSOXNumbers= @()
        # $New = $SOXArray where $n -notin $ValidatedSOXArray
        foreach ($n in $SOXArray)
        {
           if ($ValidatedSOXArray -notcontains $n)
           {
                $SkippedSOXNumbers += $n
           }
        }
        $SkippedSOXNumbersString = $SkippedSOXNumbers -join ','
        Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "SkippedSOXNumbersString" -NewValue $SkippedSOXNumbersString  
        # 1) Create Folders for Objects, if necessary
        # Write-HostAndLog "Create Folders for Objects $SOXNumbersString"
        # Write-Host "added pun path $RunPath"
        # Write-HostAndLog "After This run path identified"
        $NavFoldersArray = @()
        $RunPath = Get-ThisRunPath -SourceEnvironment $SourceEnvConfig.Name -TargetEnvironment $TargetEnvConfig.Name
        $RunPath = $RunPath -split ' ' | Select-Object -First 1
        foreach ($n in $ValidatedSOXArray)
        {
            Write-Host 'Nav Folders' + $n
            $NavFolders = New-FoldersForSOX $n -SourceEnvironment $SourceEnvConfig.Name -TargetEnvironment $TargetEnvConfig.Name -Verbose
            foreach ($f in $NavFolders)
            {
                if ($f.SOXNumber)
                {
                    $NavFoldersArray += $f
                }
            }
        }
        $LogContent = Get-Content -Path $CheckLogFilePath
        Remove-Item -Path  $CheckLogFilePath
        $global:CheckLogFilePath = $RunPath+'\'+$global:CheckLogFileName + ".log"
        New-Item -Path $CheckLogFilePath -ItemType File
        Set-Content -Path $CheckLogFilePath -Value $LogContent
        $VariablesContent = Get-Content -Path $VariablesFilePath
        Remove-Item -Path  $VariablesFilePath
        $ThisRunJSONVariablesPath = $RunPath + "\" + $pipelineStagingVariablesFileName
        $VariablesFilePath = $ThisRunJSONVariablesPath
        New-Item -Path $VariablesFilePath -ItemType File
        Set-Content -Path $VariablesFilePath -Value $VariablesContent
        $AnyObjectsToImport = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "AnyObjectsToImport"
        Write-Host "Any object to import $AnyObjectsToImport"
        Write-Host "Type: $($AnyObjectsToImport.GetType().FullName)"  # Optional for debug
        $AnyObjectsToImportTxt = "$AnyObjectsToImport"
        $result = @{
            ThisRunJSONVariablesPath = $ThisRunJSONVariablesPath
            AnyObjectsToImport = "$($AnyObjectsToImportTxt.ToLower())"  # <- Safe coercion to string
        }
        Write-Host "result.AnyObjectsToImport $($result.AnyObjectsToImport)"
        Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "CheckLogFilePath" -NewValue $CheckLogFilePath
        Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "NavFoldersArray" -NewValue $NavFoldersArray
        Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ChangedObjects" -NewValue $ChangedObjects  
        # throw 'STOP IT NOW'
        return $result
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