function Write-PriWinEvent {
    [CmdletBinding()]
    param (
        $Logname = "DevOpsLogs", $LogSource = "DevOps", $EventId = "1000", $Message = "Blank Message", $EntryType = "Information"
    )
    try {
        $maxMessageSize = 31860 #Max size of the message block on on Win 2008 R2
        if ($message.Length -gt $maxMessageSize)  {
            $message = $message.substring(0,$maxMessageSize)
        }
        
        if ([System.Diagnostics.EventLog]::SourceExists($LogSource)) {
            Write-EventLog -LogName $Logname -Source $LogSource -EventId $EventId -Message $Message -EntryType $EntryType
        } else {
            New-EventLog -LogName $Logname -Source $LogSource
            #New-WinEventLog -LogName $Logname -LogSource $LogSource
            # When a new event source is created. The events fail to write correctly. 1st event will always be blank
            #Write-EventLog -LogName $Logname -LogSource $LogSource -EventID $EventId -Message $Message -EntryType $EntryType
        }
    } catch {
        $_
        Write-Error "Failed to write event to the log file"
    }
}

function Get-PriProcess {
    [CmdletBinding()]
    param (
        $ProcName
    )
    if ((Get-Process -Name $ProcName -ErrorAction SilentlyContinue).Count -ge 1) {
        Write-Verbose "$ProcName process is running"
        return $true
    } else {
        return $false       
    }
}

Function Stop-PriProcess {
    [CmdletBinding()]
    param (
        $ProcName
    )
    Get-Process -Name $ProcName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}


Function Initialize-PriFolder ($folderPath) {
    if (!(Test-Path $folderPath)) {
        Write-Verbose "$(Get-Date -Format "HH:mm:ss") Folder Does Not Exist ($folderPath) Creating..." 
        try {
            New-Item -ItemType Directory -Force -Path $folderPath 
        } catch {
            throw "$(Get-Date -Format "HH:mm:ss") Failed to create ($folderPath) exiting... "
        }
    }
}


Export-ModuleMember *