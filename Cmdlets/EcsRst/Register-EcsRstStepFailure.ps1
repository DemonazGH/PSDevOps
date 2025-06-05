function Register-EcsRstStepFailure {
    Param([Parameter(Position=0)][String]$errorMessage_arg
         ,[Parameter(Position=1)][String]$restoreStep_arg
         )

    # Warning! This script can't be used as a pipeline separate step. It shall be called inside another pipeline step only         

    # Build failed
    Write-EcsRstOutput ("Restore has failed")

    # Remove a restore sign file to indicate the restore pipeline is finished
    #Disable-EcsRstEnvSignRestoring

    # Read the environments topology
    #Write-EcsRstOutput ("Read the environments topology")

    #Write-EcsRstOutput ("Search for the short name in the topology: $global:Restore_EnvShortName")
    #$environment = Get-CurrentEnvironmentConfig

    #if ($null -eq $environment) {
    #    throw "ERROR: Environment was not found in the topology: '$global:Restore_EnvShortName'"
    #}
    #Write-EcsRstOutput ("Found. Environment description: '$($environment.Description)'")
    #Write-EcsRstOutput (" ")

    # Send Teams message(s) in case of any errors
    $msgCaption = "Restore has failed at step: $restoreStep_arg"

    $msgCardBody = @(Initialize-EcsTmsTextBlockForAdaptiveCard -Message "$errorMessage_arg" -Spacing "None")
    Send-EcsRstMessageToTeams -messageType_arg "Error" -messageCaption_arg $msgCaption -messageText_arg $errorMessage_arg -tableItems $msgCardBody
}
<## >
Register-EcsRstStepFailure -errorMessage_arg "XXX" -restoreStep_arg "The Final Step"
<##>