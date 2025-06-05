function Get-EcsStrEnvironmentClassFromBackup {
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
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource "$LogSource" -EventID 1000 -Message "$BeginMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1

        ###### Start Script Here 
        $Start = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
        $StartTime = $(get-date)

        Write-Host "********************************************************************************" -ForegroundColor Cyan
        Write-Host "*** [$fn]" -ForegroundColor Cyan
        Write-Host "*** Started at: $Start" -ForegroundColor Cyan
        Write-Host "********************************************************************************" -ForegroundColor Cyan
        
        [boolean]$backupLoaded = $false
        $global:envClassList = $null

        # Backup 1
        Write-Host " "   
        Write-Host "--------------------------------------------------------------------------------"
        Write-Host "Backup 1: $global:globalStrapiBackupFile_1"
        try {
            # Check that backup file exists
            if (-Not(Test-Path -Path $global:globalStrapiBackupFile_1 -PathType Leaf)) {
                throw "Backup file doesn't exist: $global:globalStrapiBackupFile_1"
            }
            # Export to file
            Write-Host "Reading backup file: $global:globalStrapiBackupFile_1"
            $global:envClassList = Get-Content $global:globalStrapiBackupFile_1 | Out-String | ConvertFrom-Json
            $backupLoaded = $true
        }
        catch {
            Write-Host "Reading from backup 1 file failed" -ForegroundColor Red
            Write-Host "ERROR: $_" -ForegroundColor Red
        }
        Write-Host "--------------------------------------------------------------------------------"

        # Backup 2
        if (!$backupLoaded) {
            Write-Host " "   
            Write-Host "--------------------------------------------------------------------------------"
            Write-Host "Backup 2: $global:globalStrapiBackupFile_2"
            try {
                # Check that backup file exists
                if (-Not(Test-Path -Path $global:globalStrapiBackupFile_1 -PathType Leaf)) {
                    throw "Backup file doesn't exist: $global:globalStrapiBackupFile_1"
                }
                # Export to file
                Write-Host "Reading backup file: $global:globalStrapiBackupFile_1"
                $global:envClassList = Get-Content $global:globalStrapiBackupFile_1 | Out-String | ConvertFrom-Json
                $backupLoaded = $true
            }
            catch {
                Write-Host "Reading from backup 1 file failed" -ForegroundColor Red
                Write-Host "ERROR: $_" -ForegroundColor Red
            }
            Write-Host "--------------------------------------------------------------------------------"
        }
           
        if (!$backupLoaded) {
            throw "ERROR: Unable to load backup from all sources"
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
Get-EcsStrEnvironmentClassFromBackup
<## >
Write-Host '> List length:' $global:envClassList.Length
<##>