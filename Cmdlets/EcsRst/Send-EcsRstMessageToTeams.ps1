function Send-EcsRstMessageToTeams {
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
        [string]$teamsChannelName_arg = $global:globalRstTeamsChannelDevOps
       ,[Parameter(Mandatory=$false, Position = 4, HelpMessage = "Additional table or other items for the adaptive card.")]
        [array]$tableItems = @()
    )

    if ($teamsChannelName_arg) {
        Write-EcsRstOutput ("Trying to send a teams message to channel '$teamsChannelName_arg'")
        try {
            $teamsChannels = Get-EcsStrAllTeamsChannels
            $api = ($teamsChannels | Where-Object ChannelName -EQ $teamsChannelName_arg).API
            if ($api) {
                $Title = $global:Restore_EnvShortName + ": " + $messageCaption_arg
                $msg = "Restore ID: $global:Restore_ID"
                if ($messageType_arg -eq "Success") { $cardTitleColor = "Good" }
                if ($messageType_arg -eq "Error")   { $cardTitleColor = "Attention" }
                if ($messageType_arg -eq "Warning") { $cardTitleColor = "Warning" }

                $FactTitle = "Server: " + $env:COMPUTERNAME
                $adaptiveCard = Initialize-EcsTmsAdaptiveCard
                $adaptiveCard.body += Initialize-EcsTmsTextBlockForAdaptiveCard -Message $Title -TextColor $cardTitleColor -FontSize "large" -TextWeight "Bolder"
                $adaptiveCard.body += Initialize-EcsTmsTextBlockForAdaptiveCard -Message $msg -FontSize "Medium" -Separator $true -Spacing "None"
                $adaptiveCard.body += Initialize-EcsTmsTextBlockForAdaptiveCard -Message $FactTitle -TextWeight "Bolder" -Spacing "None" -FontSize "Medium"       
                $adaptiveCard.body += @($tableItems)

                $payloadJson = $adaptiveCard | ConvertTo-Json -Depth 10
                Invoke-RestMethod -Method Post -Uri $api -ContentType 'application/json' -Body $payloadJson
                Write-Host "Adaptive Card sent successfully." -ForegroundColor Green
                Write-EcsRstOutput ("Finished sending message to Teams")
            }
            else {
                throw "ERROR: Teams channel $teamsChannelName_arg doesn't exist in the settings or its API is empty"    
            }                                
        }
        catch {
            Write-EcsRstOutput ("Unable to send a teams message") Red
            Write-EcsRstOutput ("$_") Red
        }
    }
    else {
        Write-EcsRstOutput ("Teams channel name cannot be empty!") Yellow    
    }

}

<## >
Send-EcsRstMessageToTeams -teamsChannelName_arg 'IHFX' -messageType_arg "Success" -messageCaption_arg "Caption" -messageText_arg "Text"
<##>