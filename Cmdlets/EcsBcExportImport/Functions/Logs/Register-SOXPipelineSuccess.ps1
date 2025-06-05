function Register-SOXPipelineSuccess {
    Param(
    [Parameter(Position=2)][String]$VariablesFilePath,
    [Parameter(Position=1)][String]$TeamsChannelName,
    [Parameter(Mandatory=$false)] [String] $AnyObjectToImport
    )   
    $SkippedSOXNumbersString = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "SkippedSOXNumbersString"
    $SkippedSOXNumbers = $SkippedSOXNumbersString -split ','
    $SOXNumberArray = $SOXNumber -split ','
    # Sox number contains info
    $DeployedSOXNumbers = $SOXNumberArray | Where-Object { $_ -notin $SkippedSOXNumbers}
    $DeployedSOXNumbersString = $DeployedSOXNumbers -join ','
    
    if ($AnyObjectToImport -and $AnyObjectToImport.ToString().ToLower() -eq 'true') {
        $StatusMsg = 'Success'
        $msgCaption = "SOX Version control Pipeline has finished successfully. Details:"
        $msgType = "Success"
    }
    elseif (-not $DeployedSOXNumbers -or $DeployedSOXNumbers.Count -eq 0) {
        $StatusMsg = 'Skipped'
        $msgCaption = "SOX Version control Pipeline had no objects to deploy. Potential reason is they all have already been deployed.`n$($global:SOXNumber -join "`n")"
        $msgType = "Warning"
    }
    elseif ($SkippedSOXNumbers -and $DeployedSOXNumbers) {
        $StatusMsg = 'Some skipped some deployed'
        $msgCaption = "SOX Version control Pipeline had some objects to deploy. Potential reason is that other objects have already been deployed. Deployed:`n$DeployedSOXNumbersString, `nSkipped: `n$SkippedSOXNumbersString"
        $msgType = "Warning"
    }

    # Warning! This script can't be used as a pipeline separate step. It shall be called inside another pipeline step only         
    # Build failed
    Write-HostAndLog ("SOX Version control Pipeline has finished successfully")
    Send-SOXVersionControlMessageToTeams -messageType_arg $msgType -messageCaption_arg $StatusMsg -messageText_arg $msgCaption -teamsChannelName_arg $TeamsChannelName -VariablesFilePath $VariablesFilePath
    # Send metrics to Grafana
    # Send Teams message(s) in case of any errors
}   