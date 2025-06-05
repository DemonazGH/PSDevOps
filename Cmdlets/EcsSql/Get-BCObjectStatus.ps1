function Get-BCObjectStatus {
    [CmdletBinding()]

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

        Write-Host "********************************************************************************"
        Write-Host "*** [$fn]"
        Write-Host "*** Started at      : $Start"
        Write-Host "********************************************************************************"

        $TrackingFolder = $global:globalMainPath + "\BCDeploymentTracking"
        # Ensure the tracking directory exists
        if (-not (Test-Path $TrackingFolder)) {
            New-Item -ItemType Directory -Path $TrackingFolder -Force
        }

        # Generate the tracking file name using today's date
        $CurrentDate = (Get-Date).ToString("ddMMyyyy")
        $TrackingFile = "$TrackingFolder\$CurrentDate`_objects_to_deploy.txt"

        # Determine yesterday’s tracking file name
        $YesterdayDate = (Get-Date).AddDays(-1).ToString("ddMMyyyy")
        $YesterdayFile = "$TrackingFolder\$YesterdayDate`_objects_to_deploy.txt"

        # If this is the first run of the day, delete yesterday's tracking file
        if (Test-Path $YesterdayFile) {
            Remove-Item -Path $YesterdayFile -Force
            Write-Output "Deleted previous day's tracking file: $YesterdayFile"
        }
        
        # Ensure today's tracking file exists
        $trackingFileExists = Test-Path $TrackingFile
        if (-not $trackingFileExists) {
            New-Item -ItemType File -Path $TrackingFile -Force
        }

        # Read existing tracked objects into a HashSet for faster lookups
        $TrackedObjects = New-Object 'System.Collections.Generic.HashSet[string]'
        if ($trackingFileExists) {
            Get-Content $TrackingFile | ForEach-Object { $TrackedObjects.Add($_.Trim()) } | Out-Null
        }

        #$environment = Get-CurrentEnvironmentConfig

        # SQL Query to fetch status 425 objects along with approval and compliance status
        $Query = @"
        SELECT
            sa.[Unique Change ID] AS SOX_ID,
            sa.[Change Description] AS ObjectName,
            sa.[Expected Delivery Date] AS ExpectedDate,
            sa.[Status] AS ApprovalStatus
        FROM [SOX Approval] sa
        WHERE sa.[Status] LIKE N'425 %'
"@

        # Execute the query and store the results
        $Results = Invoke-Sqlcmd -ServerInstance $global:DataWarehouseDBServer `
                                 -Database $global:DataWarehouseDBName `
                                 -Query $Query
        $Results | Format-Table
        # If no objects found, exit
        if ($null -eq $Results -or $Results.Count -eq 0) {
            Write-Output "No objects found for deployment today."
            if (Test-Path $TrackingFile) {
                Remove-Item -Path $TrackingFile -Force
                Write-Output "Removed previously created tracking file since no objects exist."
            }
            return
        }
        # Extract IDs from SQL results
        $CurrentDatabaseObjects = $Results | ForEach-Object { $_.SOX_ID }

        # Detect New Objects
        $NewObjects = $Results | Where-Object { -not $TrackedObjects.Contains($_.SOX_ID) }
        if ($NewObjects.Count -gt 0) {
            Write-Host "New objects ready for deployment found:"
        
            foreach ($item in $NewObjects) {
                Write-Host "--------------------------------------"
                Write-Host "Unique Change ID    :" $item.SOX_ID
                Write-Host "Object Name         :" $item.ObjectName
                Write-Host "Last Updated        :" $item.ExpectedDate
                Write-Host "Status              :" $item.ApprovalStatus
            }
            Write-Host "--------------------------------------"
        }
        else {
            Write-Host "No new objects found for deployment."
        }

        # Detect Removed Objects (Objects in Tracking File But Not in Database)
        $RemovedObjects = $TrackedObjects | Where-Object { -not ($CurrentDatabaseObjects -contains $_) }
        if ($RemovedObjects.Count -gt 0) {
            Write-Output "The following objects were removed from the deployment list:"
            $RemovedObjects | ForEach-Object { Write-Output "- $_" }
        }

        # START OF TEST AREA
        $mrgQuery = @"
        MERGE INTO [azureagent].[Pending_DeploymentObjects] AS dst
        USING (
            SELECT
                sa.[Unique Change ID] AS [SOX_Number],
                sa.[Status] AS [SOX_Status],
                CAST(LEFT( sa.[Status], 3) as int) [Status]
            FROM [SOX Approval] sa
            WHERE CAST(LEFT( sa.[Status], 3) as int) >= 300 AND CAST(LEFT( sa.[Status], 3) as int) < 700
        ) as src
        ON src.[SOX_Number] COLLATE Norwegian_100_CI_AS = dst.[SOX_Number] COLLATE Norwegian_100_CI_AS
        WHEN MATCHED THEN 
            UPDATE
                SET [Status] = src.[Status],
                    [SOX_Status] = src.[SOX_Status]
        WHEN NOT MATCHED BY TARGET THEN
            INSERT ([SOX_Number], [Status], [SOX_Status], [DevOps_Status])
            VALUES (src.[SOX_Number], src.[Status], src.[SOX_Status], 0)
        WHEN NOT MATCHED BY SOURCE THEN 
            DELETE;
"@
        Write-Host "Merge query:"
        Write-Host $mrgQuery
        
        $MrgResults = Invoke-Sqlcmd -ServerInstance $global:DataWarehouseDBServer `
                                    -Database $global:DataWarehouseDBName `
                                    -Query $mrgQuery
 
        Write-Host "Rows Affected: $($MrgResults.RowsAffected)"
 
        $testSelect = @"
        SELECT
            [SOX_Number],
            [Status],
            [SOX_Status],
            [DevOps_Status]
        FROM [azureagent].[Pending_DeploymentObjects];
"@
        $TestResults = Invoke-Sqlcmd -ServerInstance $global:DataWarehouseDBServer `
                                    -Database $global:DataWarehouseDBName `
                                    -Query $testSelect
        $TestResults | Format-Table
        # END OF TEST AREA
        

        # If nothing changed, exit (no new, no removed objects)
        if ($NewObjects.Count -eq 0 -and $RemovedObjects.Count -eq 0) {
            Write-Output "No new objects detected, and no removals found. No notification sent."
            return
        }

        # Update Tracking File
        $CurrentDatabaseObjects | Out-File -FilePath $TrackingFile -Encoding UTF8 -Force
        Write-Output "Updated tracking file: $TrackingFile"
        
        # Start designing the adaptive card
        $objectTableItems = @()
        $headerColumns = @(
        (Initialize-EcsTmsColumnForAdaptiveCard -Width "140px" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message "SOX_ID" -TextWeight "Bolder" -FontSize "Large" -TextColor "Accent" -HorizontalAlignment "Left")),
        (Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Object" -TextWeight "Bolder" -FontSize "Large" -TextColor "Accent" -HorizontalAlignment "Left")),
        (Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Expected Delivery Date" -TextWeight "Bolder" -FontSize "Large" -TextColor "Accent" -HorizontalAlignment "Left")),
        (Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Status" -TextWeight "Bolder" -FontSize "Large" -TextColor "Accent" -HorizontalAlignment "Left"))
        )
        $objectTableItems += Initialize-EcsTmsColumnSetForAdaptiveCard -Columns $headerColumns -Separator $true -Spacing "Small"

        foreach ($item in $Results) {
            $dataColumns = @(
                (Initialize-EcsTmsColumnForAdaptiveCard -Width "140px" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message $item.SOX_ID -WrapText $true -HorizontalAlignment "Left")),
                (Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message $item.ObjectName -WrapText $true -HorizontalAlignment "Left")),
                (Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message $item.ExpectedDate -WrapText $true -HorizontalAlignment "Left")),
                (Initialize-EcsTmsColumnForAdaptiveCard -Width "stretch" -Items @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message $item.ApprovalStatus -WrapText $true -HorizontalAlignment "Left"))
            )
            $objectTableItems += Initialize-EcsTmsColumnSetForAdaptiveCard -Columns $dataColumns -Separator $true -Spacing "Small"
        }
        $objectTableItems += Initialize-EcsTmsTextBlockForAdaptiveCard -Message "Deployment is planned for today at 23:00 CET. If any changes are needed, notify the team immediately." `
                                                                        -FontSize "Medium" `
                                                                        -Spacing "Small" `
                                                                        -Separator $true
        try {
            $Title = "Deployment Notification: Pending Items Found"
            $adaptiveCard = Initialize-EcsTmsAdaptiveCard
            $adaptiveCard.body += Initialize-EcsTmsTextBlockForAdaptiveCard -Message $Title -TextColor "Attention" -FontSize "Large" -TextWeight "Bolder"
            $adaptiveCard.body += $objectTableItems
            $payloadJson = $adaptiveCard | ConvertTo-Json -Depth 10

            $teamsChannelNames = @('NDEV')
            foreach ($channel in $teamsChannelNames) {
                $teamsChannels = Get-EcsStrAllTeamsChannels
                $api = ($teamsChannels | Where-Object ChannelName -EQ $channel).API
                if ($api) {
                    Write-Host "API found: $api"
                    Write-Host "Sending a message to Teams channel '$channel'"
                    Invoke-RestMethod -Method Post -Uri $api -ContentType 'application/json' -Body $payloadJson
                    Write-Output "Teams notification sent successfully with $($Results.Count) objects."
                }
                else {
                    Write-Host "ERROR: Can't find teams channel '$channel' in Strapi"
                }
            }
        }
        catch {
            Write-Host "Unable to send teams notification: $_"
        }
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
Get-BCObjectStatus 
<##>

