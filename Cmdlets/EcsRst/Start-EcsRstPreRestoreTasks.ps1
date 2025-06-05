function Start-EcsRstPreRestoreTasks {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory = $false)] [string]$envShortName_arg
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

        Write-Host ("********************************************************************************")
        Write-Host ("*** [$fn]")
        Write-Host ("*** Started at : $Start")
        Write-Host ("*** ----------------------------------------------------------------------------")
    
        Write-Host "Running pre-restore tasks"
        $environment = Get-CurrentEnvironmentConfig
        [string]$bcServerInstance = $environment.TargetBCServerInstance
        [string]$dbName = $environment.DatabaseName
        [string]$dbServerName = $environment.DatabaseServerName

        Write-Host ("========================================================")
        Write-Host ("Export all $dbName database roles to the .sql file")
        Write-Host ("--------------------------------------------------------")

        Export-SQLDatabaseRoles -Environment $environment
        
        Write-Host "Export has been completed successfully"
        Write-Host ("========================================================")
        Write-Host " "
        
        Write-Host ("========================================================")
        Write-Host ("Export environment BC/NAV dev user accounts and their permission sets to the .csv file")
        Write-Host ("--------------------------------------------------------")

        Export-DevUsersAndPerms -ServerInstance $bcServerInstance
        
        Write-Host "Export has been completed successfully"
        Write-Host ("========================================================")
        Write-Host " "
        
        # TODO... 
        
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
Start-EcsRstPreRestoreTasks -envShortName_arg 'HFX'
<##>