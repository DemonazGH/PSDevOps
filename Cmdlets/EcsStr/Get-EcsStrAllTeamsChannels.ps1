function Get-EcsStrAllTeamsChannels {
    [CmdletBinding()]

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
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource "$LogSource" -EventID 1000 -Message "$BeginMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1

        ###### Start Script Here 
        $link = $Global:StrapiTeamsUrl + "?pagination[pageSize]=1000"
        Write-Host 'Retrieving data from Strapi - Teams channels'
        $response = Invoke-RestMethod $link -TimeoutSec 15
        $EnvStrapi = $response.data.attributes

        #Store the results in a PSObject to return back
        $resultObj = @()

        # Process all items from Strapi
        $EnvStrapi | ForEach-Object {
            $resultObj += New-Object -TypeName psobject -Property @{ChannelName = $_.ChannelName; API = $_.API; Description = $_.Description }
        }

        return $resultObj
        ######  End Script Here

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
    <#
    .SYNOPSIS
    .DESCRIPTION
    .PARAMETER AllPorts
    .PARAMETER UserId
    .PARAMETER EnhancedPorts
    .EXAMPLE
    .EXAMPLE
    .EXAMPLE
    .LINK
    .NOTES
    .Inputs
    .Outputs
#>
}
<## >
$res = Get-EcsStrAllTeamsChannels
$api = ($res | Where-Object ChannelName -EQ SR1).API
Write-Host 'SR1 API is' $api
#$api
<##>
