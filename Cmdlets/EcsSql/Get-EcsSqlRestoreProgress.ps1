function Get-EcsSqlRestoreProgress {
    [CmdletBinding()]
    param (
        $TmsNotificationChannel,
        $Instance
    )
    $Global:Instance = $Instance
    
    function global:GetSQLProgress {
        try {
            $progress = Invoke-Sqlcmd "SELECT session_id as SPID, command, a.text AS Query, start_time, percent_complete, dateadd(second,estimated_completion_time/1000, getdate()) as estimated_completion_time
            FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) a WHERE r.command in ('RESTORE DATABASE')" -ServerInstance $Instance
            if ($progress) {
                return $progress
            } else {
                Write-Host "No Restore in progress, ending"
                Get-EventSubscriber -Force | Unregister-Event -Force
                exit
            }
            Write-Verbose $progress.SPID; Write-Host $progress.Query; Write-Host $progress.start_time; Write-Host $progress.percent_complete; Write-Host $progress.estimated_completion_time; Write-Output $($progress.SPID); Write-Output "hello"
        } catch {
            $e = $_.Exception; $msg = $e.Message; Write-Output $msg
            Write-Error "Failed to restore"
        }
    }

    #region Timers
    function global:EchoRestoreProgressToTms {
        [CmdletBinding()]
        Param (
            $key
        )
        try {
            $TMSModulePath = "$global:rootInitializePath\Modules\PsTeams" 
            Import-Module $TMSModulePath #Import-Module again as not always loaded as nested function

            $progress = GetSQLProgress
            Write-Verbose "Restore in progress, $($progress.percent_complete) % complete" #$SPID;Query;start_time;percent_complete;estimated_completion_time
            
            $msg = "<b>Env:</b> $env:COMPUTERNAME <br> <b>Completed:</b> $($progress.percent_complete) % <br> <b>Estimated:</b> $($progress.estimated_completion_time) UTC"
            Send-TeamsMessage -Uri $sqltmskey -MessageTitle 'Restore Progress' -MessageText $msg -Color DodgerBlue
        } catch {
            $e = $_.Exception; $msg = $e.Message; Write-Output $msg
            Write-Output "!!!! Failed to send message to Teams !!!!"
            Write-Host $msg
        }
    }

    function global:EchoRestoreProgressToScreen {
        try {
            $progress = GetSQLProgress
            Write-Host "Restore in progress, $($progress.percent_complete) % complete - Estimated complete time: $($progress.estimated_completion_time) UTC " #$SPID;Query;start_time;percent_complete;estimated_completion_time           
        } catch {
            $e = $_.Exception; $msg = $e.Message; Write-Host $msg
            Write-Warning "!!!! Failed to get SQL Progress !!!!"
            Write-Warning $msg
        }
    }

    Push-Location
    $progress = Invoke-Sqlcmd "SELECT session_id as SPID, command, a.text AS Query, start_time, percent_complete, dateadd(second,estimated_completion_time/1000, getdate()) as estimated_completion_time
    FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) a WHERE r.command in ('RESTORE DATABASE')" -ServerInstance $Instance

    if ($progress) {
        Write-Host "Restore in progress, $($progress.percent_complete) % complete " #$SPID;Query;start_time;percent_complete;estimated_completion_time
    } else {
        Write-Host "No Restore in progress, ending"
        Pop-Location
        return
    }

    if ($TmsNotificationChannel) {
        Write-Verbose "Teams Notification Channel Enabled"
        $global:sqltmskey = Get-PriTmsApiKey -tmsNotificationChannel $tmsNotificationChannel 
        Write-Verbose "Using Teams API key $sqltmskey"
        $tmstimer = New-Object Timers.Timer
        Register-ObjectEvent -InputObject $tmstimer -EventName Elapsed -SourceIdentifier TeamsTimer  -Action { EchoRestoreProgressToTms }  | Out-Null
        $tmsTimer.Interval = $globalTmsRestoreNotificationInterval
        $tmsTimer.AutoReset = $true
        $tmsTimer.Start()
    }
    
    $screenTimer = New-Object Timers.Timer
    Register-ObjectEvent -InputObject $screenTimer -EventName Elapsed -SourceIdentifier ScreenTimer  -Action { EchoRestoreProgressToScreen } | Out-Null
    $screenTimer.Interval = $globalTmsRestoreScreenNotificationInterval
    $screenTimer.AutoReset = $true
    $screenTimer.Start()

    Pop-Location
    <#
.SYNOPSIS
.DESCRIPTION
.EXAMPLE
.LINK
#>
}
#endregion Timers
#Get-EcsSqlRestoreProgress -TmsNotificationChannel DevOpsLogs -Instance FRSCBVSQLAX01\AX_12_DB