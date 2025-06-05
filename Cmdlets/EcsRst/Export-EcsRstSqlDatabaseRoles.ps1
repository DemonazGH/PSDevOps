function Export-EcsRstSqlDatabaseRoles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position = 0, HelpMessage = "Unique pipeline id to check that all restore steps use correct initialization variables")]
        [string]$restorePipelineID_arg
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
    
        # Read global variables
        Get-EcsRstGlobalVariables

        Write-EcsRstOutput ("********************************************************************************") Cyan
        Write-EcsRstOutput ("*** [$fn]") Cyan
        Write-EcsRstOutput ("*** Started at : $Start") Cyan
        Write-EcsRstOutput ("*** Pipeline ID: $restorePipelineID_arg") Cyan
        Write-EcsRstOutput ("*** ----------------------------------------------------------------------------") Cyan

        # Check pipeline ID
        if (($null -eq $restorePipelineID_arg) -Or ($restorePipelineID_arg -eq '')) {
            throw "Error: Pipeline ID cannot be empty"
        }
        if ($restorePipelineID_arg -ne $global:Restore_PipelineID) {
            throw "Pipeline ID specified ($restorePipelineID_arg) is different from the pipeline ID used when initializing the restore ($global:Restore_PipelineID). Make sure you run the initialization script at the beginning"
        }
    
        # Get Current user access file name
        [string]$CurrentDbRolesFolder = $global:globalRstDatabaseRolesListFolderRoot
        $curDate = Get-Date
        [string]$curDateStr = $curDate.ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
        $global:Restore_SQLRoleMembershipFile = $CurrentDbRolesFolder + "\DatabaseRoles_$global:Restore_EnvShortName" + "_$curDateStr.sql"

        if (-Not(Test-Path -Path $CurrentDbRolesFolder)) {
            New-Item -Path $CurrentDbRolesFolder -ItemType "directory" -Force | Out-Null
        }
        if (-Not(Test-Path -Path $CurrentDbRolesFolder)) {
            throw "ERROR: Unable to create local folder: '$CurrentDbRolesFolder'"
        }

        # Delete existing output file
        if (Test-Path -Path $global:Restore_SQLRoleMembershipFile -PathType Leaf) {
            Write-EcsRstOutput ("Deleting existing output file: $global:Restore_SQLRoleMembershipFile")
            Remove-Item -Path $global:Restore_SQLRoleMembershipFile -Force
        }
        if (Test-Path -Path $global:Restore_SQLRoleMembershipFile -PathType Leaf) {
            throw "ERROR: Unable to delete existing file: $global:Restore_SQLRoleMembershipFile"
        }
        
        # Export all database roles to the .sql file
        Write-EcsRstOutput ("Export all $dbName database roles to the .sql file")
        try {
            Export-EcsDbcSqlDatabaseRoles -outputFile_arg $global:Restore_SQLRoleMembershipFile -envShortName_arg $global:Restore_EnvShortName
        }
        catch {
            Write-EcsRstOutput ("ERROR: $_")
            Write-EcsRstOutput ("The process will continue running anyway")
            $global:Restore_SQLRoleMembershipFile = ""
        }
        
        #Store the results in a PSObject
        Write-EcsRstGlobalVariables

        # Show elapsed time
        $elapsedTime = $(get-date) - $StartTime
        $totalTime = "{0:HH:mm:ss.fff}" -f ([datetime]$elapsedTime.Ticks)
        Write-EcsRstOutput (" ")
        Write-EcsRstOutput ('*** Time elapsed: ' + $totalTime.ToString()) Cyan
        Write-EcsRstOutput ("********************************************************************************") Cyan
        Write-EcsRstOutput (" ")
        Write-EcsRstOutput (" ")
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
Export-EcsRstSqlDatabaseRoles -restorePipelineID_arg 'AAA'
<##>