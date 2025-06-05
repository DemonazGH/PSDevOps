function Add-EcsUsrUserToCitrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "Environment short name (e.g. I_HFX or IHFX)")]
        [string]$envShortName_arg
       ,[Parameter(Mandatory = $true, HelpMessage = "User domain name (e.g. europe")]
        [string]$userDomain_arg
       ,[Parameter(Mandatory = $true, HelpMessage = "User name(s) (e.g. 131038 or 131038,131038admin")]
        [string]$userName_arg
)

    #region Standard Start Block
    $Private:Tmr = New-Object System.Diagnostics.Stopwatch; $Private:Tmr.Start()
    $MyParams = $PSBoundParameters | Out-String
    $ErrorActionPreference = "Stop"; $fn = '{0}' -f $MyInvocation.MyCommand
    $LogSource = $fn; $EntryType = "4" #1 Error, 2 Warning, 4 Information
    $StartTime = Get-Date((Get-Date).ToUniversalTime()) -Format HH:mm:ss
    $BeginMessage = "[$env:COMPUTERNAME-$StartTime" + "z]-[$fn]: Begin Process"    
    #endregion

    try {
        Push-Location
        Write-Host $BeginMessage
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource "$LogSource" -EventID 1000 -Message "$BeginMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1

        ###### Start Script Here 
        $Start = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
        $StartTime = $(get-date)

        Write-Host "********************************************************************************" -ForegroundColor Cyan
        Write-Host "*** [$fn]" -ForegroundColor Cyan
        Write-Host "*** Started at    : $Start" -ForegroundColor Cyan
        Write-Host "*** Env short name: $envShortName_arg" -ForegroundColor Cyan
        Write-Host "*** Domain        : $userDomain_arg" -ForegroundColor Cyan
        Write-Host "*** User          : $userName_arg" -ForegroundColor Cyan
        Write-Host "********************************************************************************" -ForegroundColor Cyan
        
        # Read the environments topology
        Write-Host 'Read the environments topology'
        $environment = Get-BCEnvironmentConfig -EnvShortName $envShortName_arg
        
        # Get environment Active directory access group
        [string]$adGroupName = $environment.ActiveDirectoryAccessGroup
        Write-Host "Environment Active Directory access group: $adGroupName"
        if ([string]::IsNullOrEmpty($adGroupName)) {
            throw "ERROR: Environment '$envShortName_arg' has no Active Directory access group specified in Strapi"
        }

        try {
            Add-EcsWinActiveDirectoryUserToGroup -adGroupName_arg $adGroupName -userDomain_arg $userDomain_arg -userName_arg $userName_arg
        }
        catch { 
            [string]$errorText = $_

            # Send Teams notification
            [string]$teamsChannelName = "BCAutoEnvRequest"
            try {
                Write-Host "Sending a message to Teams channel '$teamsChannelName'"
                $teamsChannels = Get-EcsStrAllTeamsChannels
                $api = ($teamsChannels | Where-Object ChannelName -EQ $teamsChannelName).API
                if ($api) {
                    Write-Host "API found: $api"
                    $Title = "$($environment.Name)" + ": " + "Request failed"
                    $msg = "Stage: $fn"
                    $txtBlock = @()
                    $FactTitle = "Server: " + $env:COMPUTERNAME
                    $adaptiveCard = Initialize-EcsTmsAdaptiveCard
                    $adaptiveCard.body += Initialize-EcsTmsTextBlockForAdaptiveCard -Message $Title -TextColor "Attention" -FontSize "Large" -TextWeight "Bolder"
                    $adaptiveCard.body += Initialize-EcsTmsTextBlockForAdaptiveCard -Message $msg -FontSize "Medium" -Separator $true
                    $adaptiveCard.body += Initialize-EcsTmsTextBlockForAdaptiveCard -Message $FactTitle -TextWeight "Bolder" -Spacing "None" -FontSize "Medium"       
                    
                    $headerColumns = @(
                        (Initialize-EcsTmsColumnForAdaptiveCard -Width "60px" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Message:" -TextWeight "Bolder")),
                        (Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message $errorText))
                    )
                    $adaptiveCard.body += Initialize-EcsTmsColumnSetForAdaptiveCard -Columns $headerColumns -Separator $true
                                        
                    $container = Initialize-EcsTmsContainerForAdaptiveCard -Title " " -FontSize "Small"
                    $txtBlock += Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Env short name: $envShortName_arg" -WrapText $true -Spacing "None"
                    $txtBlock += Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Domain        : $userDomain_arg" -WrapText $true -Spacing "None"
                    $txtBlock += Initialize-EcsTmsTextBlockForAdaptiveCard -Message "User          : $userName_arg" -WrapText $true -Spacing "None"
                    $container["items"] += $txtBlock
                    
                    $messageLines = @(
                        Initialize-EcsTmsColumnForAdaptiveCard -Width "80px" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Parameters:" -TextWeight "Bolder")
                        Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items $container -Separator $true
                    )
                    $adaptiveCard.body += Initialize-EcsTmsColumnSetForAdaptiveCard -Columns $messageLines -Spacing "Small" -Separator $true
                    
                    $payloadJson = $adaptiveCard | ConvertTo-Json -Depth 10
                    Invoke-RestMethod -Method Post -Uri $api -ContentType 'application/json' -Body $payloadJson
                    Write-Host "Adaptive Card sent successfully." -ForegroundColor Green
                    Write-Host "Finished sending message to Teams"
                }
                else {
                    Write-Host "ERROR: Can't find teams channel '$teamsChannelName' in Strapi"
                }
            }
            catch {
                Write-Host "Unable to send teams notification: $_"
            }

            throw $errorText
        }

        # Show elapsed time
        $elapsedTime = $(get-date) - $StartTime
        $totalTime = "{0:HH:mm:ss.fff}" -f ([datetime]$elapsedTime.Ticks)
        Write-Host 'Time elapsed:' $totalTime.ToString()
        ######  End Script Here
    }
    catch {
        $Er = $_
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource $LogSource -EventId 3000 -Message "Failed with:`r`n$Er" -EntryType 1; Start-Sleep 1
        Write-Error "[$computerName]-[$fn]: !!! Failed with: `r`n$er!!!!"
    }
    finally {
        $TSecs = [math]::Round(($Private:Tmr.Elapsed).TotalSeconds); $Private:Tmr.Stop(); Remove-Variable Tmr
        $EndTime = Get-Date((Get-Date).ToUniversalTime()) -Format HH:mm:ss
        $EndMessage = "[$env:COMPUTERNAME-$EndTime"+"z]-[$fn]:[Elapsed Time: $TSecs seconds]: End Process"
        Write-Host $EndMessage
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource "$LogSource" -EventID 2000 -Message "$EndMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1
        Pop-Location
    }
    <#
    .SYNOPSIS
    .DESCRIPTION
    .EXAMPLE
    .EXAMPLE
    .LINK
#>
}

<## >
Add-EcsUsrUserToCitrix -envShortName_arg "I_HFX" -userDomain_arg "EUROPE" -userName_arg "104573"
<##>