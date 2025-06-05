function Start-EcsRstPostRestoreTasks {
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
    $StartTime = Get-Date((Get-Date).ToUniversalTime()) -Format HH:mm:ss
    $BeginMessage = "[$env:COMPUTERNAME-$StartTime" + "z]-[$fn]: Begin Process"    
    #endregion

    try {
        Push-Location
        Write-Host $BeginMessage
        Write-PriWinEvent -LogName $globalEventsLog -LogSource "$LogSource" -EventID 1000 -Message "$BeginMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1
        try {
            ###### Start Script Here 
            $Start = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
            $StartTime = $(get-date)

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

            Write-EcsRstOutput "Running post restore tasks"
            $environment = Get-CurrentEnvironmentConfig
            [string]$bcServerInstance = $environment.TargetBCServerInstance
            [string]$dbName = $environment.DatabaseName
            [string]$dbServerName = $environment.DatabaseServerName
            [string]$envShortName = $environment.Name
            
            # Perform Iberia-specific post-restore tasks
            if ($environment.Region -eq 'Iberia') {
                Write-EcsRstOutput "Performing Iberia-specific post-restore tasks"
                Write-EcsRstOutput ("========================================================")
            
                Start-IberiaSqlTasks -Environment $environment -envShortName_arg $envShortName

                Write-EcsRstOutput "Iberia-specific post-restore tasks have been successfully completed"
                Write-EcsRstOutput ("========================================================")            
            }
            else {
                Write-EcsRstOutput "No SQL tasks are scheduled for non-Iberia environments after the database restore."
            }
        }
        catch {
            $errorMessage = $_
            # Send the error to the log
            Write-EcsRstOutput ("Error: " + $errorMessage) Red
            # Register a failed step
            Register-EcsRstStepFailure -errorMessage_arg "$errorMessage" -restoreStep_arg $fn
            throw $errorMessage
        }
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
Start-EcsRstPostRestoreTasks -restorePipelineID_arg 'AAA'
<##>