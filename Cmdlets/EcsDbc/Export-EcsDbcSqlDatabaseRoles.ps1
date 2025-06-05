function Export-EcsDbcSqlDatabaseRoles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "File path to export user access data")]
        [string]$outputFile_arg
       ,[Parameter(Mandatory = $false, Position = 1, HelpMessage = "Short name of the environment. If not set, the current server will be used to find the proper short name")]
        [string]$envShortName_arg
    )

    #region Standard Start Block
    $Private:Tmr = New-Object System.Diagnostics.Stopwatch; $Private:Tmr.Start()
    $MyParams = $PSBoundParameters | Out-String
    $ErrorActionPreference = "Stop"; $fn = '{0}' -f $MyInvocation.MyCommand
    $LogSource = $fn; $EntryType = "4" #1 Error, 2 Warning, 4 Information
    $StartTime = Get-Date
    $formattedStartTime = $StartTime.ToUniversalTime().ToString("HH:mm:ss")
    $BeginMessage = "[$env:COMPUTERNAME-$formattedStartTime" + "z]-[$fn]: Begin Process"    
    #endregion

    try {
        Push-Location
        Write-Host $BeginMessage
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource "$LogSource" -EventID 1000 -Message "$BeginMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1

        $Start = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
        $StartTime = $(get-date)

        Write-Host "********************************************************************************" -ForegroundColor Cyan
        Write-Host "*** [$fn]" -ForegroundColor Cyan
        Write-Host "*** Started at    : $Start" -ForegroundColor Cyan
        Write-Host "*** Env short name: $envShortName_arg" -ForegroundColor Cyan
        Write-Host "*** Output file   : $outputFile_arg" -ForegroundColor Cyan
        Write-Host "********************************************************************************" -ForegroundColor Cyan

        # Delete output file
        if (Test-Path -Path $outputFile_arg -PathType Leaf) {
            Write-Host "Deleting existing output file"
            Remove-Item -Path $outputFile_arg -Force
        }
        if (Test-Path -Path $outputFile_arg -PathType Leaf) {
            throw "ERROR: Unable to delete existing file: $outputFile_arg"
        }
        $environment = Get-CurrentEnvironmentConfig
        [string]$dbName = $environment.DatabaseName
        [string]$dbServerName = $environment.DatabaseServerName
        Write-Host "DB server name  : $dbServerName"
        Write-Host "DB name         : $dbName"

    
        $query = @"
            USE [$dbName];
            SELECT
                'ALTER ROLE [' + r.name + '] ADD MEMBER [' + m.name + '];' AS CreateRoleMemberStmt
            FROM sys.database_role_members drm
            JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
            JOIN sys.database_principals m ON drm.member_principal_id = m.principal_id
            WHERE r.name IN ('db_owner','public','db_datareader','db_datawriter','db_securityadmin','db_ddladmin')
                AND m.name NOT LIKE '##%'
                AND m.name NOT LIKE 'NT SERVICE%'
                AND m.name NOT IN ('guest', 'dbo');
"@
        try {
            # Run the query
            $results = Invoke-Sqlcmd -ServerInstance $dbServerName `
                                    -Database $dbName `
                                    -Query $query -ErrorAction Stop
            
            if (-not $results) {
                Write-Warning "No roles found for '$dbName' database. Nothing to export."
            }
            else {
                $roleMembershipLines = $results.CreateRoleMemberStmt
                $roleMembershipLines | Out-File -FilePath $outputFile_arg -Encoding UTF8
                Write-Host "Exported $($roleMembershipLines.Count) role-membership lines to '$outputFile_arg'"
            }
        }
        catch {
            Write-Error "Failed to export database roles: $_"
        }
        finally {
            # Show elapsed time
            $elapsedTime = $(get-date) - $StartTime
            $totalTime = "{0:HH:mm:ss.fff}" -f ([datetime]$elapsedTime.Ticks)
            Write-Host 'Time elapsed:' $totalTime.ToString()
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