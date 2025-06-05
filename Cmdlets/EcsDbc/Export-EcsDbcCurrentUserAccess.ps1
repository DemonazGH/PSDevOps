function Export-EcsDbcCurrentUserAccess {
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

        $environment = Get-CurrentEnvironmentConfig
        [string]$bcServerInstance = $environment.TargetBCServerInstance

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
        
        $users = Get-NAVServerUser -ServerInstance $bcServerInstance
        if (-not $users) {
            Write-Warning "No users found on $bcServerInstance"
            return
        }
    
        $users | Export-Csv -Path $outputFile_arg -NoTypeInformation -Encoding UTF8
        Write-Host "Exported $($users.Count) users to $outputFile_arg"

        Write-Host "Exporting user access to file: $outputFile_arg" 
        [string]$sPath = Split-Path $outputFile_arg
        if (-Not(Test-Path $sPath)) {
            Write-Host "Creating folder: $sPath"
            New-Item $sPath -ItemType Directory
        }
        $users | Export-Csv -Path $outputFile_arg -NoTypeInformation -Encoding UTF8
        Write-Host "Successfully exported $($users.Count) users & permission sets to '$outputFile_arg' file"


<## >
        
        $exportFolder = $global:globalMainPath + "UsersBackup"
    # Ensure the directory exists
    if (-not (Test-Path $exportFolder)) {
        New-Item -ItemType Directory -Path $exportFolder -Force
    }
    $outputFile = "$exportFolder\UsersBackup.csv"
    
    Write-Host "Exporting dev user accounts from BC/NAV server instance '$ServerInstance'..."
    
    # TODO: Implement cloud-based storage for Dev users account names and retrieve them here 
    # to export permissions
    
    $devObjects = @('Europe\104573a', 'Europe\104371a')
    
    # Convert each string to a PSCustomObject with property UserName
    $devUsersList = $devObjects | ForEach-Object {
        [PSCustomObject]@{
            UserName = $_
        }
    }


        # Retrieve all users matching the dev environment access list
        $userNameArray = $devUsersList | Select-Object -ExpandProperty UserName
        
        $devUsers = Get-NAVServerUser -ServerInstance $ServerInstance |
            Where-Object { $_.UserName -in $userNameArray}

        #$devUsers = Get-NAVServerUser -ServerInstance $ServerInstance |
        #   Where-Object { $_.UserName -in $devUsersList}

        if (-not $devUsers) {
            Write-Warning "No matches found in environment's users list on '$ServerInstance'."
            return
        }

        Write-Host "Found $($devUsers.Count) dev users. Gathering permission sets..."

        # Build an array to hold user + permission set info
        $exportCollection = @()

        foreach ($user in $devUsers) {
            $permissionSets = Get-NAVServerUserPermissionSet -ServerInstance $ServerInstance `
                                                            -WindowsAccount $user.UserName
            foreach ($perm in $permissionSets) {
                $exportCollection += [PSCustomObject]@{
                    UserName        = $user.UserName
                    UserSecurityId  = $user.UserSecurityID
                    PermissionSetId = $perm.PermissionSetID
                    CompanyName     = $perm.CompanyName
                    FullName        = $user.FullName
                    State           = $user.State
                    LicenseType     = $user.LicenseType
                }
            }
        }

        Write-Host "Exporting user access to file: $outputFile_arg"
        [string]$sPath = Split-Path $outputFile_arg
        if (-Not(Test-Path $sPath)) {
            Write-Host "Creating folder: $sPath"
            New-Item $sPath -ItemType Directory
        }
        $exportCollection | Export-Csv "$outputFile_arg" -NoTypeInformation
        Write-Host "Successfully exported dev users & permission sets to '$outputFile_arg' file"
        <##>
        # Show elapsed time
        $elapsedTime = $(get-date) - $StartTime
        $totalTime = "{0:HH:mm:ss.fff}" -f ([datetime]$elapsedTime.Ticks)
        Write-Host 'Time elapsed:' $totalTime.ToString()
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