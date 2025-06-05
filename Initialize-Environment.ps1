#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][ValidateSet($false, $true)][Switch]$VerboseOutput,
    [Parameter(Mandatory = $false)][Switch]$Ps7
)   
if ($VerboseOutput) {
    $global:VerbosePreference = 'Continue'
    $global:DebugPreference = 'Continue'
    $PSDefaultParameterValues['*:Verbose'] = $true
    Write-Verbose "Using Verbose Output"
    Write-Verbose "Using Debug Output"
    Write-Verbose "Setting PSDefaultParameterValues with Verbose Param"
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$global:computerName = hostname
$global:rootInitializePath = $PSScriptRoot

$startTime = Get-Date((Get-Date).ToUniversalTime()) -Format HH:mm:ss
$ErrorActionPreference = "Stop"; $fn = '{0}' -f $MyInvocation.MyCommand

$beginMessage = "[$env:COMPUTERNAME-$startTime" + "z]-[$fn]: Begin Process"

Write-Host $beginMessage
Push-Location
Set-Location $PSScriptRoot
Get-EventSubscriber | Unregister-Event
  
if(!$(Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue))
{
    Write-Host "Adding PS Gallery"
    Register-PSRepository -Default -InstallationPolicy Trusted -ErrorAction SilentlyContinue
}
$ReadLineVersion = ((Get-Module PSReadline -ListAvailable).Version).Major
if ($ReadLineVersion -lt 2) {
    write-host "Attempting to remove old PSReadline if exists, this may fail if multiple sessions open, let it fail"
    $StandardRLPath = "C:\Program Files\WindowsPowerShell\Modules\PSReadline\1.2"
    Remove-Module PSReadline -Force -Confirm:$False -ErrorAction SilentlyContinue
    Get-ChildItem -Path $StandardRLPath -Recurse | Remove-Item -force -recurse
    Remove-Item $StandardRLPath -Force -ErrorAction SilentlyContinue
    Write-Host "Installing Latest PSReadline"

    $NugetProvider = ((Get-PackageProvider nuget -Force -ErrorAction SilentlyContinue).version).major
    if ($NugetProvider -lt 2) {
        Write-Host "Install nuget"
        Install-PackageProvider -Name NuGet -Force
    }

    Install-Module PsReadline -force
}
$SqlServerModuleTargetVersion = [System.Version]::new(21,1,18256)
$SqlServerModuleVersion = (Get-Module SqlServer -ListAvailable).Version
if($SqlServerModuleVersion.Count -gt 1)
{
    Write-Host "Multiple PS SqlServer modules detected"
    $SqlServerModuleVersion = $null
}
elseif($SqlServerModuleVersion.Count -eq 1) {
    Write-Host "Current PS SqlServer module is $($SqlServerModuleVersion.ToString())"
}
else {
    Write-Host "There is no PS SqlServer module detected"
    # Install-Module -Name SqlServer -RequiredVersion $SqlServerModuleTargetVersion.ToString() -Confirm $false
}

try {   
    Write-Verbose "Load variables..."
    $vars = Get-Content ".\Configs\Global.cfg"; foreach ($var in $vars) { Invoke-Expression $var }
    if($Global:StrapiMajorVersion -lt 5) {$Global:StrapiResultLocation = 'data.attributes'} else {$Global:StrapiResultLocation = 'data'}
    
    Remove-Module DevOps -ErrorAction SilentlyContinue
    Remove-Item "$globalMainPath$globalMainName.psm1" -Force -ErrorAction SilentlyContinue

    $mainModule = "$globalMainPath$globalMainName.psm1"

    Write-Verbose "Constructing public cmdlets..."

    $privateFiles = Get-ChildItem .\Cmdlets -Include *.ps1 -Recurse
    $privateFiles | Get-Content | Add-Content $mainModule

    Write-Verbose "Constructing export items..."
    $string = "$($privateFiles.BaseName)"
    $string = $string -replace ' ', ','
    $string = "Export-ModuleMember -Function $string"
    $string | Add-Content $mainModule
    
    Write-Verbose "Importing necessary modules..."
    Get-ChildItem .\Modules -Include *.ps1, *.psm1, *.psd1 -Recurse | ForEach-Object { Import-Module $_.FullName -Global -WarningAction SilentlyContinue}

    Write-Host "Environment initialization complete." -ForegroundColor Yellow
    Import-Module $mainModule  -Global -DisableNameChecking 
    
    if (!(Get-Module ActiveDirectory -ListAvailable)) {
        Write-Host "ActiveDirectory Module is not installed, attempting to install now..."
        Install-WindowsFeature RSAT-AD-PowerShell
    }
    
    if (!(Get-Module DbaTools -ListAvailable)) {
        Write-Host "DbaTools Module is not installed, attempting to install now..."
        try {
            # Ensure PSGallery is trusted to avoid interactive prompts
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction SilentlyContinue

            # Attempt installation
            Install-Module -Name dbatools -Force -RequiredVersion 1.1.146 -Confirm:$false -ErrorAction Stop
            Write-Host "dbatools installed successfully."
        }
        catch {
            Write-Warning "Failed to install dbatools. Continuing without it. Error: $($_.Exception.Message)"
        }
               
    }

    #Global script block to allow remote initialistion of module
    [ScriptBlock] $global:InitRemoteModule = {
        $Ws   = "O:\Agent"
        $Filename = "Initialize-Environment.ps1"
    
        $LatestGitFolderObjs = Get-ChildItem -Path $ws -Recurse -Directory ".git" -Force | Sort-Object LastWriteTime
        $LatestBuildFolderObj = $LatestGitFolderObjs | Select-Object -Last 1
        $LatestBuildFolder = ($LatestBuildFolderObj).FullName -replace ".git"   
        $FullPath = Join-Path $LatestBuildFolder $Filename
   
        # Load Standard Script
        if ($LatestGitFolderObjs) {
            Invoke-Expression $FullPath
        } else {
            Write-Warning "Unable to find $File, failed to load modules correctly"
        }
    }

    $EndTime = Get-Date((Get-Date).ToUniversalTime()) -Format HH:mm:ss
    $endMessage = "[$env:COMPUTERNAME-$EndTime" + "z]-[$fn]: End Process"
    Write-Output $endMessage
} 
catch {
    $e = $_.Exception; $msg = $e.Message; Write-Output $msg
    Write-Output "[$computerName] Failed to initilise environment correctly, quiting"
    throw $_    # Fail if environment has not been initialized correctly
}
finally {
    Pop-Location
}