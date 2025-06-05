function Write-ImplementationObjectsDataToAdaptiveCardTable {
    [CmdletBinding()]
    param (
        [PSCustomObject]
        $ImplementationObjectsArr
    )

    try {
        if ($ImplementationObjectsArr) {
            $objectTableItems = @()
            $headerColumns = @(
            (Initialize-EcsTmsColumnForAdaptiveCard -Width "140px" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Type" -TextWeight "Bolder" -FontSize "Large" -TextColor "Accent" -HorizontalAlignment "Left")),
            (Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message "ID" -TextWeight "Bolder" -FontSize "Large" -TextColor "Accent" -HorizontalAlignment "Left")),
            (Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Name" -TextWeight "Bolder" -FontSize "Large" -TextColor "Accent" -HorizontalAlignment "Left")),
            (Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message "VersionList" -TextWeight "Bolder" -FontSize "Large" -TextColor "Accent" -HorizontalAlignment "Left"))
            )
            $objectTableItems += Initialize-EcsTmsColumnSetForAdaptiveCard -Columns $headerColumns -Separator $true -Spacing "None"

            foreach ($item in $ImplementationObjectsArr) {
                $dataColumns = @(
                    (Initialize-EcsTmsColumnForAdaptiveCard -Width "140px" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message $item.ObjectType -WrapText $true -HorizontalAlignment "Left")),
                    (Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message $item.ID -WrapText $true -HorizontalAlignment "Left")),
                    (Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message $item.Name -WrapText $true -HorizontalAlignment "Left")),
                    (Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message $item.VersionList -WrapText $true -HorizontalAlignment "Left"))
                )
                $objectTableItems += Initialize-EcsTmsColumnSetForAdaptiveCard -Columns $dataColumns -Separator $true -Spacing "None"
            }
    }
    }
    catch {
        Write-HostAndLog "Error $_"
    }
    <#Do this after the try block regardless of whether an exception occurred or not#>
    return $objectTableItems
}

function Write-ServicesArrayToAdaptiveCardTable {
    [CmdletBinding()]
    param (
        [array] $ServicesArr
    )

    $objectTableItems = @()  # Ensure initialization

    try {
        if ($ServicesArr) {
            # Header row
            $headerColumns = @(
                (Initialize-EcsTmsColumnForAdaptiveCard -Width "140px" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Services may require manual start:" -TextWeight "Bolder" -FontSize "Medium" -TextColor "Accent" -HorizontalAlignment "Left"))
            )
            $objectTableItems += Initialize-EcsTmsColumnSetForAdaptiveCard -Columns $headerColumns -Separator $true -Spacing "None"

            # Data rows
            foreach ($item in $ServicesArr) {
                $dataColumns = @(
                    (Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message $item -WrapText $true -HorizontalAlignment "Left"))
                )
                $objectTableItems += Initialize-EcsTmsColumnSetForAdaptiveCard -Columns $dataColumns -Separator $true -Spacing "None"
            }
        }
    }
    catch {
        Write-HostAndLog "Error $_"
    }

    return $objectTableItems
}



function Send-SOXVersionControlMessageToTeams {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position = 0, HelpMessage = "Message type")]
        [ValidateSet("Success", "Error", "Warning", "Info")]
        [string]$messageType_arg
       ,[Parameter(Mandatory=$true, Position = 1, HelpMessage = "Message caption")]
        [string]$messageCaption_arg
       ,[Parameter(Mandatory=$true, Position = 2, HelpMessage = "Message text")]
        [string]$messageText_arg
       ,[Parameter(Mandatory=$false, Position = 3, HelpMessage = "Teams channel name")]
        [string]$teamsChannelName_arg = $global:globalHthTeamsChannelDevOps
        ,[Parameter(Mandatory=$false, Position = 4, HelpMessage = "Implementation Deployment Comment (deadline)")]
        [string]$notificationOnTimeWhenShouldDeploy_arg
        ,[Parameter(Mandatory=$true, Position = 5, HelpMessage = "Variables File Path")]
        [string]$VariablesFilePath
        
    )
    if ($teamsChannelName_arg) {
        Write-HostAndLog ("Trying to send a teams message to channel '$teamsChannelName_arg'")
        try {
            $teamsChannels = Get-EcsStrAllTeamsChannels
            $api = ($teamsChannels | Where-Object ChannelName -EQ $teamsChannelName_arg).API
            if ($api) {
                Write-HostAndLog ("API found: $api")
                $Title = $messageCaption_arg
                $msg = "Server: " + $env:COMPUTERNAME

   
                if ($messageType_arg -eq "Success") { $cardColor = "Good" }
                if ($messageType_arg -eq "Error")   { $cardColor = "Attention" }
                if ($messageType_arg -eq "Warning") { $cardColor = "Warning" }
                
                $adaptiveCard = Initialize-EcsTmsAdaptiveCard
                $container = Initialize-EcsTmsContainerForAdaptiveCard -Title $Title -TitleColor $cardColor -FontSize "Large"
                $textBlockServer = Initialize-EcsTmsTextBlockForAdaptiveCard -Message $msg 
                $textBlockMessage = Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Message: $messageText_arg" -TextWeight "Bolder" -Spacing "Large"
                
                $container["items"] += $textBlockServer
                if (($env:SOURCEENVTYPE) -and ($env:TARGETENVTYPE))
                {
                    $direction = "Direction: $env:SOURCEENVTYPE - $env:TARGETENVTYPE"
                    $textBlockDirection = Initialize-EcsTmsTextBlockForAdaptiveCard -Message $direction 
                    $container["items"] += $textBlockDirection
                }
                if (($env:SOXNUMBER))
                {
                    $soxNumber = "SOX Number: $env:SOXNUMBER"
                    $textBlockSOXNumber = Initialize-EcsTmsTextBlockForAdaptiveCard -Message $soxNumber 
                    $container["items"] += $textBlockSOXNumber
                }
                $container["items"] += $textBlockMessage
                if ($notificationOnTimeWhenShouldDeploy_arg) 
                {
                    $notificationWhenToDeploy += Initialize-EcsTmsTextBlockForAdaptiveCard -Message $notificationOnTimeWhenShouldDeploy_arg `
                    -FontSize "Medium"  -Spacing "Small"  -Separator $true
                    $container["items"] += $notificationWhenToDeploy
                }
                $JsonKeyExists = Confirm-KeyExistsInJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ChangedObjects"
                if ($JsonKeyExists)
                {
                    $ChangedObjects = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ChangedObjects"
                    $notificationWhenToDeploy += Initialize-EcsTmsTextBlockForAdaptiveCard -Message ' '
                    $container["items"] += $notificationWhenToDeploy
                    $objectsDataTable = Write-ImplementationObjectsDataToAdaptiveCardTable $ChangedObjects
                    $container["items"] += $objectsDataTable
                }
                
                $JsonKeyExists = Confirm-KeyExistsInJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ServicesToRestart"
                if (($messageType_arg -eq 'Error') -and ($JsonKeyExists))
                {
                    $ServicesToRestart = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ServicesToRestart"
                    $servicesToRestartText2 += Write-ServicesArrayToAdaptiveCardTable -ServicesArr $ServicesToRestart
                    #$ServicesToRestartData = Write-ImplementationObjectsDataToAdaptiveCardTable $ChangedObjects
                    if ($servicesToRestartText2) 
                    {
                        $container["items"] += $servicesToRestartText2
                    }
                }
                $adaptiveCard.body += $container

                $payloadJson = $adaptiveCard | ConvertTo-Json -Depth 10
                Write-HostAndLog ("Finished sending message to Teams") -color Green
                Invoke-RestMethod -Method Post -Uri $api -ContentType 'application/json' -Body $payloadJson
                Write-HostAndLog -message  "Adaptive Card sent successfully." -color Green
            }
            else {
                throw "ERROR: Teams channel $teamsChannelName_arg doesn't exist in the settings or its API is empty"    
            }                                
        }
        catch {
            Write-HostAndLog -message "Unable to send a teams message" -color Red
            Write-HostAndLog -message  "$_" -color Red
        }
    }
    else {
        Write-HostAndLog -message  "Teams channel name cannot be empty!"
    }

}