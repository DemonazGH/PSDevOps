function Write-EcsRstOutput {
    Param([Parameter(Position=0)][String]$message
         ,[Parameter(Position=1)][ConsoleColor]$color = (get-host).ui.rawui.ForegroundColor
         )

    Write-Host $message -ForegroundColor $color
    if  (-not [string]::IsNullOrWhiteSpace($global:Restore_LogFile)) {      
        Add-content $global:Restore_LogFile -value $message
    }
}
