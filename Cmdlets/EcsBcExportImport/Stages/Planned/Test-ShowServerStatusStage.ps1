function Test-ShowServerStatusStage
{
    [CmdletBinding()]
    param(
            [Parameter(Mandatory=$true)][String] $TargetEnvType
            # [Parameter(Mandatory=$true)][String] $VariablesFilePath
    )
    try {
        # $fn = '{0}' -f $MyInvocation.MyCommand
        # Write-InitialLogs -fn $fn
        # $jsonPath = Get-EnvironmentsConfigJSONFilePath
        # # $ObjectSetIncludesTable = Get-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "ObjectSetIncludesTable"
       
        # $TargetEnvConfig = Get-EnvironmentConfig -EnvironmentType $TargetEnvType -RelativeFilePath $jsonPath
        # $LicenseImportRequired = Get-EnvironmentConfig -EnvironmentType $TargetEnvType -RelativeFilePath $jsonPath
        Write-Host "##[group]Beginning of a group"
        Write-Host "##[warning]Warning message"
        Write-Host "##[error]Error message"
        Write-Host "##[section]Start of a section"
        Write-Host "##[debug]Debug text"
        Write-Host "##[command]Command-line being run"
        Write-Host "##[endgroup]"
        Write-Host "Client"
        ShowServerStatus2 -Server "FRSCBVNAPP002Q"
        Write-Host "NAS"
        ShowServerStatus2 -Server "FRSCBVNAPP003Q"
        Write-Host "SQL"
        ShowServerStatus2 -Server "FRSCBVNSQL001Q"
    }
    catch {
        # $errorMessage = $_
        # Write-Host($_)
        # Write-HostAndLog "Error: $errorMessage" 
        # Register-SOXPipelineStepFailure -ErrorMessageArg $errorMessage -StepArg $fn -VariablesFilePath $VariablesFilePath
        # throw $errorMessage
    }
    finally
    {
        # Write-LogsToFile -Message $LogBuffer.ToString() -VariablesPath $VariablesFilePath
    }
} 

function ShowServerStatus2([String] $Server) {

  
    $s = New-PSSession -ComputerName $Server
    Invoke-Command -Session $s -ScriptBlock {
    
    Import-Module -name "C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\navadmintool.ps1" -Verbose:$false > $null 
      $Serverinstances=Get-NAVServerInstance
      foreach ($Instance in $Serverinstances) {
  
  
        $ServiceState = Get-Service -Name $instance.ServerInstance
  
        $skip=$false
        if ($ServiceState.StartType -eq "Disabled") {$skip=$true}
        if ($instance.Version.Substring(0,2) -ne "14") {$skip=$true}
  
        if (-not $skip) {
  
  
            $locHost = hostname
            $Color="##[section]"
            if ($instance.State -eq "Running") {
              $Tenant=  get-navtenant $instance.ServerInstance
              if ($Tenant.State -ne "Operational") {$Color="##[error]"}
              $Result=$locHost+" "+$instance.ServerInstance.PadRight(55)+$instance.State.PadRight(20)+$tenant.DatabaseName+"   "+  $Tenant.State
              write-host "$Color$Result" 
            } else
                  {
                  $Color="##[error]"
                  $Result=$locHost+" "+$instance.ServerInstance.PadRight(55)+$instance.State.PadRight(20)
                  write-host "$Color$Result" 
                  }
            }
        } #//Disabled
      }
    }
  