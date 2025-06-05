function Register-SOXPipelineStepFailure {
    Param([Parameter(Position=0)][String]$ErrorMessageArg,
    [Parameter(Position=1)][String]$StepArg,
    [Parameter(Position=2)][String]$VariablesFilePath,
    [Parameter(Position=1)][String]$TeamsChannelName
         )
    # Warning! This script can't be used as a pipeline separate step. It shall be called inside another pipeline step only         
    # Build failed
    Write-HostAndLog "SOX Version control Pipeline has failed"
    $msgCaption = "SOX Version control Pipeline has failed at step: $StepArg"
    Send-SOXVersionControlMessageToTeams -messageType_arg "Error" -messageCaption_arg $msgCaption -messageText_arg $ErrorMessageArg -teamsChannelName_arg $TeamsChannelName -VariablesFilePath $VariablesFilePath
   }   