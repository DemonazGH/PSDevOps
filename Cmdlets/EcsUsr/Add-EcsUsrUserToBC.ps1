function Add-EcsUsrUserToBC {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$userID_arg,
        [Parameter(Mandatory = $true)] [string]$userDomain_arg,
        [Parameter(Mandatory = $true)] [string]$permissionSetID_arg,
        [Parameter(Mandatory = $true)] [string]$envShortName_arg,
        [Parameter(Mandatory = $false)] [string]$companyName_arg # Optional for company-specific permissions
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
        Write-PriWinEvent -LogName $globalEventsLog -LogSource "$LogSource" -EventID 1000 -Message "$BeginMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1

        ###### Start Script Here 
        $Start = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
        $StartTime = $(get-date)
        $envShortName_arg = $envShortName_arg.ToUpper()
        Write-Host "********************************************************************************"
        Write-Host "*** [$fn]"
        Write-Host "*** Started at      : $Start"
        Write-Host "*** User            : $userID_arg"
        Write-Host "*** Domain          : $userDomain_arg"
        Write-Host "*** PermissionSetID : $permissionSetID_arg"
        Write-Host "*** Env short name  : $envShortName_arg"
        Write-Host "*** Company Name    : $companyName_arg"
        Write-Host "********************************************************************************"
        
        try 
        {
            $removalErrorText = @()
            $AssignedSoFar = @()
            
            # Get current environment configuration
            $environment = Get-CurrentEnvironmentConfig
            [string]$bcServerInstance = $environment.TargetBCServerInstance
            
            Write-Host "DB server name                            : $($environment.DatabaseServerName)"
            Write-Host "DB name                                   : $($environment.DatabaseName)"
            Write-Host "Business Central\NAV service instance name: $bcServerInstance"
            Write-Host " "

            # Convert semicolon-separated string to an array
            $userList = $userID_arg -split ';'
            $permissionSetsList = $permissionSetID_arg -split ';' | ForEach-Object { $_.Trim() }
            $availablePermissionSets = Get-NAVServerPermissionSet -ServerInstance $bcServerInstance | Select-Object -ExpandProperty PermissionSetID
            if (!$availablePermissionSets) {
                throw "Failed to retrieve the list of PermissionSetIDs from the server instance '$bcServerInstance'."
            }
            
            foreach ($user in $userList) {
                $UserName = "$($userDomain_arg.Trim())\$($user.Trim())"
                # Validate the user exists
                Write-Host "Checking user: $UserName in environment: $envShortName_arg"
                $result = Get-NAVServerUser -ServerInstance $bcServerInstance | Where-Object { $_.UserName -eq $UserName }
                if (-not $result) {
                    Write-Host "User $UserName could not be found in the $envShortName_arg environment."
                    Write-Host "Trying to create a new user for $envShortName_arg environment..."
                    try {
                        New-NAVServerUser -serverinstance $bcServerInstance -windowsaccount $UserName
                        $result = Get-NAVServerUser -ServerInstance $bcServerInstance | Where-Object { $_.UserName -eq $UserName }
                        Write-Host "User has been created:"
                        $result | Format-List
                    }
                    catch {
                        throw "Failed to create '$UserName' for $envShortName_arg environment. Reason: $_"
                    }
                }
                else {
                    Write-Host "User found:"
                    $result | Format-List                        
                } 
                # Get all PermissionSetIDs assigned to the user
                $existingAssignments = Get-NAVServerUserPermissionSet `
                                        -ServerInstance $bcServerInstance `
                                        -WindowsAccount $UserName `
                                        | Select-Object -ExpandProperty PermissionSetId

                foreach ($permissionSet in $permissionSetsList) {
                    if ($existingAssignments -contains $permissionSet) {
                        Write-Host "PermissionSet '$permissionSet' is already assigned to $UserName.  Skipping."
                        continue
                    }
                    # Validate the permission set
                    if ($availablePermissionSets -notcontains $permissionSet) {
                        Write-Host "PermissionSetID $permissionSet does not exist in the system."
                        throw "PermissionSetID $permissionSet does not exist in the system."
                    }
                    Write-Host "PermissionSetID '$permissionSet' exists in the system."
                    Write-Host "Trying to assign '$permissionSet' PermissionSetID to '$UserName' user."
                    try {
                        New-NAVServerUserPermissionSet `
                            -ServerInstance $bcServerInstance `
                            -WindowsAccount $UserName `
                            -PermissionSetId $permissionSet `
                            -CompanyName $companyName_arg
    
                        Write-Host "Assigned '$permissionSet' to '$UserName'."
                        
                        # If we got this far, it succeeded. Record it for potential rollback.
                        $AssignedSoFar += [PSCustomObject]@{
                            UserName        = $UserName
                            PermissionSetId = $permissionSet
                            CompanyName     = $companyName_arg
                        }
                    }
                    catch {
                        throw "Failed to assign '$permissionSet' to '$UserName'. Reason: $_"
                    }
                }
            }
            Write-Host "All permission assignments completed successfully."
        }
        catch {
            $originalError = $_.Exception.Message
            Write-Host "An error occurred: $originalError"

            if ($AssignedSoFar) {
                Write-Host "Rolling back assigned permissions..."
                foreach ($assignment in $AssignedSoFar) {
                    try {
                        Remove-NAVServerUserPermissionSet `
                            -ServerInstance $bcServerInstance `
                            -WindowsAccount $assignment.UserName `
                            -PermissionSetId $assignment.PermissionSetId `
                            -CompanyName $assignment.CompanyName `
                            -Confirm:$false -Force

                        Write-Host "Rolled back '$($assignment.PermissionSetId)' from '$($assignment.UserName)'."
                    }
                    catch {
                        # If removing fails for some reason, just log it. 
                        Write-Host "Failed to remove '$($assignment.PermissionSetId)' for '$($assignment.UserName)': $_"
                        $removalErrorText += $_.Exception.Message
                    }
                }
            }

            # Handle errors
            if ($removalErrorText.Count -gt 0) {
                $rollbackErrors = $removalErrorText -join "`n"
                $errorText = "Pipeline execution failed. Not all changes were rolled back successfully." +
                    "`nRollback errors:`n$rollbackErrors"
            }
            else {
                $errorText = "Pipeline execution failed. No changes were applied." +
                    "`nOriginal error: $originalError"
            }

            Write-Host $errorText
            [string]$teamsChannelName = "BCAutoEnvRequest"
            try {
                Write-Host "Sending a message to Teams channel '$teamsChannelName'"
                $teamsChannels = Get-EcsStrAllTeamsChannels
                $api = ($teamsChannels | Where-Object ChannelName -EQ $teamsChannelName).API
                if ($api) {
                    Write-Host "API found: $api"
                    $Title = "$envShortName_arg" + ": " + "Request failed"
                    $msg = "Stage: $fn"
                    $FactTitle = "Server: " + $env:COMPUTERNAME
                    $txtBlock = @()
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
                    $txtBlock += Initialize-EcsTmsTextBlockForAdaptiveCard -Message "User           : $userID_arg" -WrapText $true -Spacing "None"
                    $txtBlock += Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Domain         : $userDomain_arg" -WrapText $true -Spacing "None"
                    $txtBlock += Initialize-EcsTmsTextBlockForAdaptiveCard -Message "PermissionSetID: $permissionSetID_arg" -WrapText $true -Spacing "None"
                    $txtBlock += Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Env short name : $envShortName_arg" -WrapText $true -Spacing "None"
                    $container["items"] += $txtBlock
                    
                    $messageLines = @(
                        Initialize-EcsTmsColumnForAdaptiveCard -Width "80px" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Parameters:" -TextWeight "Bolder")
                        Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items $container -Separator $true
                    )
                    $adaptiveCard.body += Initialize-EcsTmsColumnSetForAdaptiveCard -Columns $messageLines -Spacing "Small" -Separator $true

                    $payloadJson = $adaptiveCard | ConvertTo-Json -Depth 10
                    Invoke-RestMethod -Method Post -Uri $api -ContentType 'application/json' -Body $payloadJson
                    Write-Host "Adaptive Card sent successfully."
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
}
<## >
Add-EcsUsrUserToBC -userID_arg '104371a' -userDomain_arg 'Europe ' -permissionSetID_arg 'SUPER ; ADCS RETRY ' -envShortName_arg 'bcuat'
<##>