function Backup-EcsStrEnvironmentClass {
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
        
        # Read environments
        Write-Host "Reading environments topology"
        Get-EcsStrDataAsClass -doNotReadFromBackup

        [int]$days = 15
        $curDate = Get-Date
        $dateLimit = $curDate.AddDays(-$days)
        [string]$curDateStr = $curDate.ToUniversalTime().ToString('yyyyMMddTHHmmssZ')

        # Backup 1
        Write-Host " "   
        Write-Host "--------------------------------------------------------------------------------"
        Write-Host "Backup 1: $global:globalStrapiBackupFile_1"

        [string]$folderPath = [string]::Join('\', $global:globalStrapiBackupFile_1.Split('\')[0..$($global:globalStrapiBackupFile_1.Split('\').Length-2)])
        Write-Host "Folder path: $folderPath"

        # Delete files older than the $dateLimit
        Write-Host "Deleting all files older then $dateLimit"
        Get-ChildItem -Path $folderPath -Force  | Where-Object { !$_.PSIsContainer -and $_.LastWriteTime -lt $dateLimit } | ForEach-Object {
            [string]$fileFullName = $_.FullName
            Write-Host "Deleting file: $fileFullName"
            Remove-Item -Path $fileFullName -Force
        }

        [string]$backupFileWithDate = $folderPath + "\StrapiBackup_" + $curDateStr + ".json"
        # Delete existing backup file
        if (Test-Path -Path $global:globalStrapiBackupFile_1 -PathType Leaf) {
            Write-Host "Deleting existing backup file"
            Remove-Item -Path $global:globalStrapiBackupFile_1 -Force
        }
        if (Test-Path -Path $global:globalStrapiBackupFile_1 -PathType Leaf) {
            throw "ERROR: Unable to delete existing file: $global:globalStrapiBackupFile_1"
        }
        if (Test-Path -Path $backupFileWithDate -PathType Leaf) {
            Write-Host "Deleting existing backup file"
            Remove-Item -Path $backupFileWithDate -Force
        }
        if (Test-Path -Path $backupFileWithDate -PathType Leaf) {
            throw "ERROR: Unable to delete existing file: $backupFileWithDate"
        }

        # Export to file
        Write-Host "Exporting backup to file: $global:globalStrapiBackupFile_1"
        [string]$sPath = Split-Path $global:globalStrapiBackupFile_1
        if (-Not(Test-Path $sPath)) {
            Write-Host "Creating folder: $sPath"
            New-Item $sPath -ItemType Directory
        }
        $global:envClassList | ConvertTo-Json -depth 100 | Out-File $global:globalStrapiBackupFile_1

        Write-Host "Exporting backup to file: $backupFileWithDate"
        $global:envClassList | ConvertTo-Json -depth 100 | Out-File $backupFileWithDate
        Write-Host "--------------------------------------------------------------------------------"

        # Backup 2
        Write-Host " "   
        Write-Host "--------------------------------------------------------------------------------"
        Write-Host "Backup 2: $global:globalStrapiBackupFile_2"

        [string]$folderPath = [string]::Join('\', $global:globalStrapiBackupFile_2.Split('\')[0..$($global:globalStrapiBackupFile_2.Split('\').Length-2)])
        Write-Host "Folder path: $folderPath"

        # Delete files older than the $dateLimit
        Write-Host "Deleting all files older then $dateLimit"
        Get-ChildItem -Path $folderPath -Force  | Where-Object { !$_.PSIsContainer -and $_.LastWriteTime -lt $dateLimit } | ForEach-Object {
            [string]$fileFullName = $_.FullName
            Write-Host "Deleting file: $fileFullName"
            Remove-Item -Path $fileFullName -Force
        }

        [string]$backupFileWithDate = $folderPath + "\StrapiBackup_" + $curDateStr + ".json"
        # Delete existing backup file
        if (Test-Path -Path $global:globalStrapiBackupFile_2 -PathType Leaf) {
            Write-Host "Deleting existing backup file"
            Remove-Item -Path $global:globalStrapiBackupFile_2 -Force
        }
        if (Test-Path -Path $global:globalStrapiBackupFile_2 -PathType Leaf) {
            throw "ERROR: Unable to delete existing file: $global:globalStrapiBackupFile_2"
        }
        if (Test-Path -Path $backupFileWithDate -PathType Leaf) {
            Write-Host "Deleting existing backup file"
            Remove-Item -Path $backupFileWithDate -Force
        }
        if (Test-Path -Path $backupFileWithDate -PathType Leaf) {
            throw "ERROR: Unable to delete existing file: $backupFileWithDate"
        }

        # Export to file
        Write-Host "Exporting backup to file: $global:globalStrapiBackupFile_2"
        [string]$sPath = Split-Path $global:globalStrapiBackupFile_2
        if (-Not(Test-Path $sPath)) {
            Write-Host "Creating folder: $sPath"
            New-Item $sPath -ItemType Directory
        }
        $global:envClassList | ConvertTo-Json -depth 100 | Out-File $global:globalStrapiBackupFile_2

        Write-Host "Exporting backup to file: $backupFileWithDate"
        $global:envClassList | ConvertTo-Json -depth 100 | Out-File $backupFileWithDate
        Write-Host "--------------------------------------------------------------------------------"
                
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
Backup-EcsStrEnvironmentClass
<##>