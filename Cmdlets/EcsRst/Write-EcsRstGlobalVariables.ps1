function Write-EcsRstGlobalVariables {
    [CmdletBinding()]

    [string]$windowsTempFolder = [environment]::GetEnvironmentVariable("temp","machine")
    [string]$variablesFile = $windowsTempFolder + "\BCRestoreValues.json"
    Write-EcsRstOutput ("Saving global restore variables to file: $variablesFile")

    # Delete variables file
    if (Test-Path -Path $variablesFile -PathType Leaf) {
        Remove-Item -Path $variablesFile -Force
    }
    if (Test-Path -Path $variablesFile -PathType Leaf) {
        throw 'ERROR: Unable to delete existing restore global variables file: ' + $variablesFile
    }

    $resultObj = @{Restore_PipelineID  = $global:Restore_PipelineID;
        Restore_Type                   = $global:Restore_Type;
        Restore_EnvShortName           = $global:Restore_EnvShortName;
        Restore_ID                     = $global:Restore_ID;
        Restore_StartDateTime          = $global:Restore_StartDateTime;
        Restore_StartStr               = $global:Restore_StartStr;
        Restore_OutputFolderLocal      = $global:Restore_OutputFolderLocal;
        Restore_LogFile                = $global:Restore_LogFile;
        Restore_TeamsChannel           = $global:Restore_TeamsChannel;
        Restore_SQLBackupFile          = $global:Restore_SQLBackupFile;
        Restore_SQLBackupFileLocal     = $global:Restore_SQLBackupFileLocal;
        Restore_KeepBCUserAccess       = $global:Restore_KeepBCUserAccess;
        Restore_SQLReplicationFound    = $global:Restore_SQLReplicationFound;
        Restore_CurrentUserAccessFile  = $global:Restore_CurrentUserAccessFile;
        Restore_SQLRoleMembershipFile  = $global:Restore_SQLRoleMembershipFile;
        Restore_ServicesToRestart      = $global:Restore_ServicesToRestart

        # Hidden values
        Restore_SkipAllSteps           = $global:Restore_SkipAllSteps;
        Restore_SkipNextStep           = $global:Restore_SkipNextStep;
    }

    $resultObj | ConvertTo-Json | Out-File $variablesFile
    if (-Not(Test-Path -Path $variablesFile -PathType Leaf)) {
        throw "ERROR: Unable to create restore global variables file: $variablesFile"
    }
}