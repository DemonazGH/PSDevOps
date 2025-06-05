function Import-EcsDbcSqlDatabaseRoles {
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "File path to import user access data")]
        [string]$inputFile_arg
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
        Write-Host "*** [$fn]"
        Write-Host "*** Started at    : $Start"
        Write-Host "*** Env short name: $envShortName_arg"
        Write-Host "*** Input file    : $inputFile_arg"
        Write-Host "********************************************************************************" -ForegroundColor Cyan

        # Check input file
        if (-Not(Test-Path -Path $inputFile_arg -PathType Leaf)) {
            throw "ERROR: Input file doesn't exist: $inputFile_arg"
        }

        $environment = Get-CurrentEnvironmentConfig
        [string]$dbName = $environment.DatabaseName
        [string]$dbServerName = $environment.DatabaseServerName
        
        try {
            Invoke-Sqlcmd -ServerInstance $dbServerName -Database $dbName `
                        -InputFile $inputFile_arg `
                        -ErrorAction Stop
        }
        catch {
            throw "Could not import database roles due to the: $_ "
        }
        $roleItems = (Get-Content $inputFile_arg).Count
        Write-Host "$roleItems database roles were successfully imported."
        
        # Show elapsed time
        $elapsedTime = $(get-date) - $StartTime
        $totalTime = "{0:HH:mm:ss.fff}" -f ([datetime]$elapsedTime.Ticks)
        Write-Host (" ")
        Write-Host ('*** Time elapsed: ' + $totalTime.ToString()) Cyan
        Write-Host ("********************************************************************************") Cyan
        Write-Host (" ")
        Write-Host (" ")
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