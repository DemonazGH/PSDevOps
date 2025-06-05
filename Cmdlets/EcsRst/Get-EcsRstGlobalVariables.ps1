function Get-EcsRstGlobalVariables {
    [CmdletBinding()]

    [string]$windowsTempFolder = [environment]::GetEnvironmentVariable("temp","machine")
    [string]$variablesFile = $windowsTempFolder + "\BCRestoreValues.json"
    Write-Host "Reading restore global variables from file: $variablesFile"

    if (-Not(Test-Path -Path $variablesFile -PathType Leaf)) {
        throw "ERROR: Restore global variables file does't exist: $variablesFile"
    }
    $JsonVars = Get-Content -Raw -Path "$variablesFile" | Out-String | ConvertFrom-Json
    
    $global:Restore_PipelineID             = $JsonVars.Restore_PipelineID
    $global:Restore_Type                   = $JsonVars.Restore_Type
    $global:Restore_EnvShortName           = $JsonVars.Restore_EnvShortName
    $global:Restore_ID                     = $JsonVars.Restore_ID
    $global:Restore_StartDateTime          = $JsonVars.Restore_StartDateTime
    $global:Restore_StartStr               = $JsonVars.Restore_StartStr
    $global:Restore_OutputFolderLocal      = $JsonVars.Restore_OutputFolderLocal
    $global:Restore_LogFile                = $JsonVars.Restore_LogFile
    $global:Restore_TeamsChannel           = $JsonVars.Restore_TeamsChannel
    $global:Restore_SQLBackupFile          = $JsonVars.Restore_SQLBackupFile
    $global:Restore_SQLBackupFileLocal     = $JsonVars.Restore_SQLBackupFileLocal
    $global:Restore_KeepBCUserAccess       = $JsonVars.Restore_KeepBCUserAccess
    $global:Restore_SQLReplicationFound    = $JsonVars.Restore_SQLReplicationFound
    $global:Restore_CurrentUserAccessFile  = $JsonVars.Restore_CurrentUserAccessFile
    $global:Restore_SQLRoleMembershipFile  = $JsonVars.Restore_SQLRoleMembershipFile
    $global:Restore_ServicesToRestart      = $JsonVars.Restore_ServicesToRestart

    # Hidden variables
    $global:Restore_SkipAllSteps           = $JsonVars.Restore_SkipAllSteps
    $global:Restore_SkipNextStep           = $JsonVars.Restore_SkipNextStep
}