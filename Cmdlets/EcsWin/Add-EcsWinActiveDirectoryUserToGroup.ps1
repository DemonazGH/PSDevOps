function Add-EcsWinActiveDirectoryUserToGroup {
    [CmdletBinding()]
    param (        
        [Parameter(Mandatory = $true, HelpMessage = "Active directory group name")]
        [string]$adGroupName_arg
       ,[Parameter(Mandatory = $true, HelpMessage = "User domain name (e.g. europe")]
        [string]$userDomain_arg
       ,[Parameter(Mandatory = $true, HelpMessage = "User name(s) (e.g. 131038 or 131038,131038admin")]
        [string]$userName_arg
       ,[Parameter(Mandatory = $false, HelpMessage = "Domain name to use")]
        [string]$useDomain_arg
    )
    #region Standard Start Block
    $Private:Tmr = New-Object System.Diagnostics.Stopwatch; $Private:Tmr.Start()
    $MyParams = $PSBoundParameters | Out-String
    $ErrorActionPreference = "Stop"; $fn = '{0}' -f $MyInvocation.MyCommand
    $LogSource = $fn; $EntryType = "4" #1 Error, 2 Warning, 4 Information
    $StartTime = Get-Date((Get-Date).ToUniversalTime()) -Format HH:mm:ss
    $BeginMessage = "[$env:COMPUTERNAME-$StartTime" + "z]-[$fn]:[$Service]: Begin Process"
    #endregion

    try {
        Write-Host $BeginMessage
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource "$LogSource" -EventID 1000 -Message "$BeginMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1

        # 
        Write-Host "********************************************************************************" -ForegroundColor Cyan
        Write-Host "*** [$fn]" -ForegroundColor Cyan
        Write-Host "*** Started at    : $StartTime" -ForegroundColor Cyan
        Write-Host "*** AD group name : $adGroupName_arg" -ForegroundColor Cyan
        Write-Host "*** User domain   : $userDomain_arg" -ForegroundColor Cyan
        Write-Host "*** User name(s)  : $userName_arg" -ForegroundColor Cyan
        Write-Host "*** Use domain    : $useDomain_arg" -ForegroundColor Cyan
        Write-Host "********************************************************************************" -ForegroundColor Cyan
        Write-Host " "

    
        Write-Host "Adding users to domain group: $adGroupName_arg"
        
        [string]$userDomainName = ""
        if ($userDomain_arg.ToUpper() -eq "EUROPE") {
            $userDomainName = "eu.corp.arrow.com"
        }
        if ($userDomain_arg.ToUpper() -eq "EUECS") {
            $userDomainName = "euecs.corp.arrow.com"
        }
        if ($userDomain_arg.ToUpper() -eq "ARROWNAO") {
            $userDomainName = "arrownao.corp.arrow.com"
        }
        if ($userDomain_arg.ToUpper() -eq "AP") {
            $userDomainName = "ap.corp.arrow.com"
        }
        if ([string]::IsNullOrEmpty($userDomainName)) {
            throw "ERROR: AD domain is unknown: $userDomain_arg"
        }

        [string]$userTmp = $userName_arg
        $userTmp = $userTmp.replace(';', ',')
        $userList = $userTmp.Split(',')
        foreach($u in $userList) {
            [string]$user = $u
            [string]$user = $user.Trim()
            Write-Host " "
            Write-Host "[User: $user]"

            $userObj = Get-AdUser -Server $userDomainName -filter "SamAccountName -eq '$user'"
            if ($null -eq $userObj) {
                throw "ERROR: User was not found: $user"
            }

            try {
                if ([string]::IsNullOrEmpty($useDomain_arg)) {
                    Add-ADGroupMember -Identity $adGroupName_arg -Members $userObj 
                }
                else {
                    Add-ADGroupMember -Identity $adGroupName_arg -Members $userObj -Server $useDomain_arg
                }
                Write-Host "User has been added"

                # Check if user was added
                Write-Host "Checking if user exists in the AD group..."
                if ([string]::IsNullOrEmpty($useDomain_arg)) {
                    $userCheck = Get-ADGroupMember -Identity $adGroupName_arg | Where-Object {$_.SamAccountName -eq $user}
                }
                else {
                    $userCheck = Get-ADGroupMember -Identity $adGroupName_arg -Server $useDomain_arg | Where-Object {$_.SamAccountName -eq $user}
                }
                if ($null -ne $userCheck) {
                    Write-Host "...success"
                }
                else {
                    throw "ERROR: User '$user' has not been added to domain '$adGroupName_arg'"
                }                
            }
            catch {
                Write-Host "Error adding user '$user' to the domain group '$adGroupName_arg'!"
                throw $_
            }
        }

    }
    catch {
        $er = $_
        Write-PriWinEvent -LogName $globalEventsLog -LogSource $LogSource -EventId 3000 -Message "Failed with:`r`n$er" -EntryType $EntryType; Start-Sleep 1
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
.EXAMPLE
.LINK
#>
}
<## >
Add-EcsWinActiveDirectoryUserToGroup -envShortName_arg "TRN" -userDomain_arg "europe" -userName_arg "131038, 131038admin"
<##>