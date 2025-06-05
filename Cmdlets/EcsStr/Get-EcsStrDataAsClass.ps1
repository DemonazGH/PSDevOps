# ---------------------------------------------------------------------------------------------
# Environment description class - BEGIN
# ---------------------------------------------------------------------------------------------
class BCServerServiceRestart {
    [string]  $ServerName
    [string[]]$Services
}

class ArrowEnvironment
{
    # For backup purpose
    [string]$backUpDateTimeLabelUTC = ""

    # Primary mandatory values
    [ValidateNotNullOrEmpty()][string]$Name                 # Short name (unique)
    #[ValidateNotNullOrEmpty()][string]$Description          # Description
    #[ValidateNotNullOrEmpty()][string]$DatabaseServerName   # Database server
    #[ValidateNotNullOrEmpty()][string]$DatabaseName         # Database
    #[string]$AGName                                         # Availability Group name
    [string]$DatabaseInstanceName                           # Database instance (if not default)

    # Server lists
    $AOS                                        # List of AOS servers
    $BAT                                        # List of Batch servers
    $SRS                                        # List of SRS servers
    $LBS                                        # List of Load balancers
    $INT                                        # List of Integration AOS servers
    $SQLNode                                    # List of SQL server nodes (failover cluster only)
    $BATSpecialConfigRaw                        # List of Batches special configs. Format SERVER{Threads-Start-End;Threads-Start-End...},SERVER{}
    $BAT_Schedule                               # List of schedules for the corresponding BAT server
    $JumpBox                                    # List of jump boxes
    $ServerAtlas                                # List of Atlas servers
    $ServerBOG                                  # List of BOG.net servers
    $ServerFiles                                # List of File servers servers
    $ServerBizTalk                              # List of BizTalk servers
    $ClusteredWith                              # List of clustered environments short names. It's impossible to restore all environments in a cluster, at least one must be online

    # HVR Settings
    [string]$HVRConfig                          #HVR Config name
    [string]$HVRChannel                         #HVR Channel name
    [bool]$IsHVRConfigured                      #Is HVR configured (Config selected and channel is set)

    # Secondary values 
    [string]$Lifecycle                          # Lifecicle - expiry date (date as string)
    [string]$EnvType                            # Environment type (AX, Nordics, Iberia)
    [string]$Platform                           # Platform used (string description)
    [string]$OwnerPrimaryID                     # Primary owner ID
    [string]$OwnerPrimaryName                   # Primary owner name
    [string]$OwnerPrimaryEmail                  # Primary owner email
    [string]$OwnerSecondaryID                   # Secondary owner ID
    [string]$OwnerSecondaryName                 # Secondary owner name
    [string]$OwnerSecondaryEmail                # Secondary owner email
    [string]$ApproverID                         # Approver ID
    [string]$ApproverName                       # Approver name
    [string]$ApproverEmail                      # Approver email
    [string]$EnvCreated                         # Date when created (date as string)
    [string]$EnvTFSBranch                       # TFS branch
    [string]$EnvAccessType                      # Access type
    [string]$EnvAXVersion                       # AX version: R2 or R3
    [string]$EnvTeamsChannelName                # Teams channel name for the environment
    [string]$ActiveDirectoryAccessGroup         # Active Directory access group to grant Citrix access
    [boolean]$dmz                               # If environment is in DMZ
    [boolean]$LockDataRefresh                   # Lock (deny) data refreshes
    [boolean]$LockCodeRefresh                   # Lock (deny) code refreshes
    [string]$User_AOS                           # Environment AOS user
    [string]$User_BCP                           # Environment BCP user
    [string]$DailyDeploymentsFrom               # Daily deployemnt from a specified TFS Branch (none,Release,Develop,Maintain)
    [int]$BatchThreadCount                      # Batch thread count (default value)

    # Integrations
    [boolean]$FastPath                          # If FastPath enabled or not
    [boolean]$SqlReplication                    # If SQL replication is set up or not
    [boolean]$TrustSQLCertificate               # If we trust server certificate
    [boolean]$LegacyReplicationModule           # If SQL legacy replication management module should be used
    [boolean]$V1                                # If V1 integration enabled or not

    # Configuration
    [string]$ReplicationPublication             # Replication publication
    [string]$ReplicationSubscriber              # Replication subscriber
    [string]$ReplicationDestinationDB           # Replication destination DB
    [string]$ReplicationInstance                # Replication instance
    [string]$ReportsServerURLSuffix             # Report server URL suffix
    [string]$ReportsReportManagerURLSuffix      # Report server manager suffix
    [string]$ReportsReportServiceSuffix         # Report server service name suffix
    [string]$ReportsServerInstance              # Report server Instance (if not default)
    [string]$DIXFFolder                         # DIXF folder setup
    [string]$ConfigurationClientUSR             # Path to an AX *.axc file pointer to the USR layer
    [string]$ConfigurationClientCUS             # Path to an AX *.axc file pointer to the CUS layer
    [int]$ConfigurationAOSBufferSize            # AOS buffer size
    [string]$CommonScriptsReconfigure           # Name of the sql script to run when reconfiguring (\Configs\EnvInitialization\<name>.sql)
    $SpecificScriptsReconfigure                 # List of Paths to environment specific reconfiguration scripts (ps1 or sql)
    [string]$CommonScriptsDeployment            # Name of the sql script to run when deploying (\Configs\EnvDeployment\<name>.sql)
    $SpecificScriptsDeployment                  # List of Paths to environment specific deployment scripts (ps1 or sql)
    [boolean]$Development                       # If it's a development environment
    $TFSMapping                                 # List of TFS mapping lines

    # Access
    [boolean]$KeepUserAccessAfterDataRestore    # Export/Import an environment AX user access when restoring data
    [boolean]$KeepSVCParametersAfterDataRestore # Export/Import an environment AX user access when restoring data
    [boolean]$KeepProdUsersAfterDataRestore     # Do not disable Prod users when restoring data
    $AccessSysAdmin                             # List of AD users/groups which with System Admin role in AX
    $AccessSysAdminTemp                         # List of AD users/groups which with System Admin temporary role in AX
    $AccessSecAdmin                             # List of AD users/groups which with Secutity Admin role in AX
    $AccessOtherRoles                           # List of AD users/groups with their AX roles. Each array item: <Role>@<User>

    [boolean]$OneBox                            # Is it a OneBox environment or not
    [datetime]$LifecycleDate                    # Lifecicle - expiry date
    [datetime]$EnvCreatedDate                   # Creation date

     # ---- BC/Nav14 fields ----
     [ValidateNotNullOrEmpty()][string]$Description
     [ValidateNotNullOrEmpty()][string]$DatabaseServerName
     [ValidateNotNullOrEmpty()][string]$DatabaseName
     [ValidateNotNullOrEmpty()][string]$TargetBCServerName
     [ValidateNotNullOrEmpty()][string]$TargetBCServerInstance
     [string]$CompanyNameToOperate
     [string]$ObjectCodeToImport
     [string]$ObjectCodeAfterImport
     [string]$Region
     [int]$ManagementPort
     [BCServerServiceRestart[]] $ServersWithServicesToRestart
     [string[]]$DevUserList

 
    # Methods
    [string[]] ToString(){
        [string]$s = "[`n"
        # Primary mandatory values
        $s += "--== Environment ==--" + "`n"
        $s += "Name                         : " + $this.Name + "`n"
        $s += "Description                  : " + $this.Description + "`n"
        $s += "DatabaseServerName           : " + $this.DatabaseServerName + "`n"
        $s += "DatabaseName                 : " + $this.DatabaseName + "`n"
        $s += "TargetBCServerName           : " + $this.TargetBCServerName + "`n"
        $s += "TargetBCServerInstance       : " + $this.TargetBCServerInstance + "`n"
        $s += "AGName                       : " + $this.AGName + "`n"
        $s += "DatabaseInstanceName         : " + $this.DatabaseInstanceName + "`n"
        # Server lists
        $s += "AOS                          : " + $this.AOS + " (" + $this.AOS.Length.ToString() + ")" + "`n"
        $s += "BAT                          : " + $this.BAT + " (" + $this.BAT.Length.ToString() + ")" + "`n"
        $s += "SRS                          : " + $this.SRS + " (" + $this.SRS.Length.ToString() + ")" + "`n"
        $s += "LBS                          : " + $this.LBS + " (" + $this.LBS.Length.ToString() + ")" + "`n"
        $s += "INT                          : " + $this.INT + " (" + $this.INT.Length.ToString() + ")" + "`n"
        $s += "SQL nodes                    : " + $this.SQLNode + " (" + $this.SQLNode.Length.ToString() + ")" + "`n"        
        $s += "BAT special config           : " + $this.BATSpecialConfigRaw + " (" + $this.BATSpecialConfigRaw.Length.ToString() + ")" + "`n"
        $s += "JumpBox                      : " + $this.JumpBox +       " (" + $this.JumpBox.Length.ToString()       + ")" + "`n"
        $s += "ServerAtlas                  : " + $this.ServerAtlas +   " (" + $this.ServerAtlas.Length.ToString()   + ")" + "`n"
        $s += "ServerBOG                    : " + $this.ServerBOG +     " (" + $this.ServerBOG.Length.ToString()     + ")" + "`n"
        $s += "ServerFiles                  : " + $this.ServerFiles +   " (" + $this.ServerFiles.Length.ToString()   + ")" + "`n"
        $s += "ServerBizTalk                : " + $this.ServerBizTalk + " (" + $this.ServerBizTalk.Length.ToString() + ")" + "`n"
        $s += "ClusteredWith                : " + $this.ClusteredWith + " (" + $this.ClusteredWith.Length.ToString() + ")" + "`n"        
        
        # HVR values
        $s += "HVR Config name              : " + $this.HVRConfig + " (" + $this.HVRConfig.Length.ToString() + ")" + "`n"
        $s += "HVR Channel name             : " + $this.HVRChannel + " (" + $this.HVRChannel.Length.ToString() + ")" + "`n"
        
        # Secondary values
        $s += "OneBox                       : " + $this.OneBox + "`n"
        $s += "Lifecycle                    : " + $this.Lifecycle + " (" + $this.LifecycleDate + ")" + "`n"
        $s += "EnvType                      : " + $this.EnvType + "`n"        
        $s += "Platform                     : " + $this.Platform + "`n"
        $s += "OwnerPrimaryID               : " + $this.OwnerPrimaryID + "`n"
        $s += "OwnerPrimaryName             : " + $this.OwnerPrimaryName + "`n"
        $s += "OwnerPrimaryEmail            : " + $this.OwnerPrimaryEmail + "`n"
        $s += "OwnerSecondaryID             : " + $this.OwnerSecondaryID + "`n"
        $s += "OwnerSecondaryName           : " + $this.OwnerSecondaryName + "`n"
        $s += "OwnerSecondaryEmail          : " + $this.OwnerSecondaryEmail + "`n"
        $s += "ApproverID                   : " + $this.ApproverID + "`n"
        $s += "ApproverName                 : " + $this.ApproverName + "`n"
        $s += "ApproverEmail                : " + $this.ApproverEmail + "`n"
        $s += "EnvCreated                   : " + $this.EnvCreated + " (" + $this.EnvCreatedDate + ")" + "`n"
        $s += "EnvTFSBranch                 : " + $this.EnvTFSBranch + "`n"
        $s += "EnvAccessType                : " + $this.EnvAccessType + "`n"
        $s += "EnvAXVersion                 : " + $this.EnvAXVersion + "`n"
        $s += "EnvTeamsChannelName          : " + $this.EnvTeamsChannelName + "`n"
        $s += "ActiveDirectoryAccessGroup   : " + $this.ActiveDirectoryAccessGroup + "`n"
        $s += "DMZ                          : " + $this.dmz + "`n"
        $s += "LockDataRefresh              : " + $this.LockDataRefresh + "`n"
        $s += "LockCodeRefresh              : " + $this.LockCodeRefresh + "`n"
        $s += "User_AOS                     : " + $this.User_AOS + "`n"
        $s += "User_BCP                     : " + $this.User_BCP + "`n"
        $s += "DailyDeploymentsFrom         : " + $this.DailyDeploymentsFrom + "`n"
        $s += "BatchThreadCount             : " + $this.BatchThreadCount + "`n"
        # Integrations
        $s += "FastPath                     : " + $this.FastPath + "`n"
        $s += "SQL replication              : " + $this.SqlReplication + "`n"
        $s += "SQL certificate trust        : " + $this.TrustSQLCertificate + "`n"
        $s += "Legacy replication module    : " + $this.LegacyReplicationModule + "`n"
        $s += "V1                           : " + $this.V1 + "`n"
        # Configuration
        $s += "--== Configuration ==--" + "`n"
        $s += "ReplicationPublication       : " + $this.ReplicationPublication + "`n"
        $s += "ReplicationSubscriber        : " + $this.ReplicationSubscriber + "`n"
        $s += "ReplicationDestinationDB     : " + $this.ReplicationDestinationDB + "`n"
        $s += "ReplicationInstance          : " + $this.ReplicationInstance + "`n"
        $s += "ReportsServerURLSuffix       : " + $this.ReportsServerURLSuffix + "`n"
        $s += "ReportsReportManagerURLSuffix: " + $this.ReportsReportManagerURLSuffix + "`n"
        $s += "ReportsReportServiceSuffix   : " + $this.ReportsReportServiceSuffix + "`n"
        $s += "ReportsServerInstance        : " + $this.ReportsServerInstance + "`n"
        $s += "DIXFFolder                   : " + $this.DIXFFolder + "`n"
        $s += "ConfigurationClientUSR       : " + $this.ConfigurationClientUSR + "`n"
        $s += "ConfigurationClientCUS       : " + $this.ConfigurationClientCUS + "`n"
        $s += "ConfigurationAOSBufferSize   : " + $this.ConfigurationAOSBufferSize + "`n"
        $s += "CommonScriptsReconfigure     : " + $this.CommonScriptsReconfigure + "`n"
        $s += "SpecificScriptsReconfigure   : " + $this.SpecificScriptsReconfigure + " (" + $this.SpecificScriptsReconfigure.Length.ToString() + ")" + "`n"
        $s += "CommonScriptsDeployment      : " + $this.CommonScriptsDeployment + "`n"
        $s += "SpecificScriptsDeployment    : " + $this.SpecificScriptsDeployment + " (" + $this.SpecificScriptsDeployment.Length.ToString() + ")" + "`n"
        $s += "Development                  : " + $this.Development + "`n"
        $s += "TFSMapping                   : " + $this.TFSMapping     + " (" + $this.TFSMapping.Length.ToString() + ")" + "`n"
            # Access
        $s += "--== Access ==--" + "`n"
        $s += "KeepUserAccessAfterDataRestore: " + $this.KeepUserAccessAfterDataRestore + "`n"
        $s += "KeepSVCParametersAfterDataRestore: " + $this.KeepSVCParametersAfterDataRestore + "`n"
        $s += "KeepProdUsersAfterDataRestore : " + $this.KeepProdUsersAfterDataRestore + "`n"        
        $s += "AccessSysAdmin                : " + $this.AccessSysAdmin     + " (" + $this.AccessSysAdmin.Length.ToString() + ")" + "`n"
        $s += "AccessSysAdminTemp            : " + $this.AccessSysAdminTemp + " (" + $this.AccessSysAdminTemp.Length.ToString() + ")" + "`n"
        $s += "AccessSecAdmin                : " + $this.AccessSecAdmin     + " (" + $this.AccessSecAdmin.Length.ToString() + ")" + "`n"
        $s += "AccessOtherRoles              : " + $this.AccessOtherRoles   + " (" + $this.AccessOtherRoles.Length.ToString() + ")" + "`n"
            # BC
        $s += "Region                        : " + $this.Region + "`n"
        $s += "ObjectCodeToImport            : " + $this.ObjectCodeToImport + "`n"
        $s += "ObjectCodeAfterImport         : " + $this.ObjectCodeAfterImport + "`n"
        $s += "]"
        return $s
    }
    # We should get rid of these static variables
    static [string]$ListSeparator             = $global:aeClassListSeparator
    static [string]$bscItemsSeparator         = $global:aeClassBscItemsSeparator
    static [string]$bscItemsScheduleSeparator = $global:aeClassBscItemsScheduleSeparator
    static [string]$RoleUserSeparator         = $global:aeClassRoleUserSeparator
    static [string]$defaultBatchSchedule      = "24"    + [ArrowEnvironment]::bscItemsScheduleSeparator + 
                                                "0"     + [ArrowEnvironment]::bscItemsScheduleSeparator + 
                                                "86399"

} 

# ---------------------------------------------------------------------------------------------
# Environment description class - END
# ---------------------------------------------------------------------------------------------

# **************************************
# Internal functions - START
# **************************************
function EcsStrInternal-ReadAccessValue {
    [CmdletBinding()]
    Param([Parameter(Mandatory = $true)][string]$accessValue_arg
         ,[Parameter(Mandatory = $false)][switch]$otherRoles
         )

    $accessArray = @()     

    [string]$curRole = ""
    [string]$s = ""
    $lines = $accessValue_arg -split "\r?\n|\r" #"`r`n"
    ForEach ($line in $lines) {
        $s = $line
        $s = $s.Trim()
        # Remove all characters after a comment symbol
        $idx = $s.IndexOf("#")
        if ($idx -ne -1) {
            $s = $s.Substring(0, $idx).Trim()
        }

        if ($otherRoles -And (-Not([string]::IsNullOrEmpty($s)))) {
            if (($s[0] -eq "[") -And ($s[$s.Length-1] -eq "]")) {
                $s = $s.Substring(1, $s.Length-2)
                $curRole = $s
                $s = ""
            }
            else {
                if ($curRole -ne "") {
                    $s = $curRole + [ArrowEnvironment]::RoleUserSeparator + $s
                }
                else {
                    Write-Host "WARNING: No role was specified for AD user/group '$s' in field 'OtherRoles'. This line was skipped" -ForegroundColor Yellow
                    $s = ""
                }
            }
        }

        if (-Not([string]::IsNullOrEmpty($s))) {
            $accessArray += $s
        }
    }    

    return $accessArray
}
# **************************************
# Internal functions - END
# **************************************


function Get-EcsStrDataAsClass {
    [CmdletBinding()]
        Param(
        [Parameter(Mandatory = $false)]
        [switch]$failInCaseOfDataErrors
       ,[Parameter(Mandatory = $false)]
        [switch]$doNotReadFromBackup
       ,[Parameter(Mandatory = $false)]
        [switch]$noOutput
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
        if (!$noOutput) {
            Write-Host $BeginMessage
        }
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource "$LogSource" -EventID 1000 -Message "$BeginMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1

        ###### Start Script Here 
        $Start = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
        $StartTime = $(get-date)
       
        #[string]$ListSeparator = ","

        # Clear variable
        $global:envClassList = @()
        $errorList = @()
        $infoMsgList = @()
        $environmentNames = @()
        [string]$s = ''
        [boolean]$dataLoaded = $false

        try {
            # ---------------------------------------------------------------------------------------
            # Get the data from Strapi - Environments
            # ---------------------------------------------------------------------------------------
            $link = $Global:StrapiEnvUrl + "?pagination[pageSize]=1000"
            try {
                $response = Invoke-RestMethod $link -TimeoutSec 15
                $EnvStrapi = Invoke-Expression "`$response.$($Global:StrapiResultLocation)"
            }
            catch {
                Write-Host "Strapi - Environments" -ForegroundColor Red
                Write-Host "ERROR: Cannot read data from link: $link" -ForegroundColor Red
                throw $_
            }

            # Process all items from Strapi
            $EnvStrapi | ForEach-Object {
                if ($_.EnvType -eq 'AX') { # We don't need to process AX envs for BC/NAV case
                    $infoMsgList += "[INFO] Environment '" + $_.EnvShortName + "' skipped: Not a BC/NAV environment"
                    return # Move to the next item
                }
                
                $E = [ArrowEnvironment]@{}

                $curDate = Get-Date
                $E.backUpDateTimeLabelUTC = $curDate.ToUniversalTime().ToString('yyyyMMddTHHmmssZ')

                # Get all list values as strings
                [string]$s_AOSServerName       = $_.AOSServerName
                [string]$s_BatchServerName     = $_.BatchServerName
                [string]$s_SRSServerName       = $_.SRSServerName
                [string]$s_LBServerName        = $_.LBServerName
                [string]$s_INTServerName       = $_.INTServerName
                [string]$s_DatabaseServerNodes = $_.DatabaseServerNodes
                [string]$s_BatchSpecialConfig  = $_.BatchSpecialConfig
                [string]$s_EnvJumpBox          = $_.EnvJumpBox
                [string]$s_ServerAtlas         = $_.ServerAtlas
                [string]$s_ServerBOG           = $_.ServerBOG
                [string]$s_ServerFiles         = $_.ServerFiles
                [string]$s_ServerBizTalk       = $_.ServerBizTalk
                [string]$s_ClusteredWith       = $_.ClusteredWith

                # Remove spaces from all list values
                $s_AOSServerName       = $s_AOSServerName.Replace(" ", "")
                $s_BatchServerName     = $s_BatchServerName.Replace(" ", "")
                $s_SRSServerName       = $s_SRSServerName.Replace(" ", "")
                $s_LBServerName        = $s_LBServerName.Replace(" ", "")
                $s_INTServerName       = $s_INTServerName.Replace(" ", "")
                $s_DatabaseServerNodes = $s_DatabaseServerNodes.Replace(" ", "")
                $s_BatchSpecialConfig  = $s_BatchSpecialConfig.Replace(" ", "")
                $s_EnvJumpBox          = $s_EnvJumpBox.Replace(" ", "")
                $s_ServerAtlas         = $s_ServerAtlas.Replace(" ", "")
                $s_ServerBOG           = $s_ServerBOG.Replace(" ", "")
                $s_ServerFiles         = $s_ServerFiles.Replace(" ", "")
                $s_ServerBizTalk       = $s_ServerBizTalk.Replace(" ", "")
                $s_ClusteredWith       = $s_ClusteredWith.Replace(" ", "")
        
                # Primary mandatory values
                if (($null -ne $_.EnvShortName)        -And ($_.EnvShortName -ne ''))         { $E.Name                 = $_.EnvShortName }
                if (($null -ne $_.EnvDescription)      -And ($_.EnvDescription -ne ''))       { $E.Description          = $_.EnvDescription }
                #if (($null -ne $_.DatabaseServerName)  -And ($_.DatabaseServerName -ne ''))   { $E.DatabaseServerName   = $_.DatabaseServerName }
                #if (($null -ne $_.DatabaseName)        -And ($_.DatabaseName -ne ''))         { $E.DatabaseName         = $_.DatabaseName }
                #if (($null -ne $_.AGName)              -And ($_.AGName -ne ''))               { $E.AGName               = $_.AGName }
                if (($null -ne $_.DatabaseInstanceName)-And ($_.DatabaseInstanceName -ne '')) { $E.DatabaseInstanceName = $_.DatabaseInstanceName }
                
                <## >
                # Server lists
                #if (-Not([string]::IsNullOrEmpty($s_AOSServerName)))       { $E.AOS                 = $s_AOSServerName.Split([ArrowEnvironment]::ListSeparator) }   else { $E.AOS = $E.DatabaseServerName }
                #if (-Not([string]::IsNullOrEmpty($s_BatchServerName)))     { $E.BAT                 = $s_BatchServerName.Split([ArrowEnvironment]::ListSeparator) } else { $E.BAT = $E.DatabaseServerName }
                #if (-Not([string]::IsNullOrEmpty($s_SRSServerName)))       { $E.SRS                 = $s_SRSServerName.Split([ArrowEnvironment]::ListSeparator) }   else { $E.SRS = $E.DatabaseServerName }
                #if (-Not([string]::IsNullOrEmpty($s_LBServerName)))        { $E.LBS                 = $s_LBServerName.Split([ArrowEnvironment]::ListSeparator) }
                if (-Not([string]::IsNullOrEmpty($s_INTServerName)))       { $E.INT                 = $s_INTServerName.Split([ArrowEnvironment]::ListSeparator) }
                if (-Not([string]::IsNullOrEmpty($s_DatabaseServerNodes))) { $E.SQLNode             = $s_DatabaseServerNodes.Split([ArrowEnvironment]::ListSeparator) }            
                if (-Not([string]::IsNullOrEmpty($s_BatchSpecialConfig)))  { $E.BATSpecialConfigRaw = $s_BatchSpecialConfig.Split([ArrowEnvironment]::ListSeparator) } 
                if (-Not([string]::IsNullOrEmpty($s_EnvJumpBox)))          { $E.JumpBox             = $s_EnvJumpBox.Split([ArrowEnvironment]::ListSeparator) } 
                if (-Not([string]::IsNullOrEmpty($s_ServerAtlas)))         { $E.ServerAtlas         = $s_ServerAtlas.Split([ArrowEnvironment]::ListSeparator) } 
                if (-Not([string]::IsNullOrEmpty($s_ServerBOG)))           { $E.ServerBOG           = $s_ServerBOG.Split([ArrowEnvironment]::ListSeparator) } 
                if (-Not([string]::IsNullOrEmpty($s_ServerFiles)))         { $E.ServerFiles         = $s_ServerFiles.Split([ArrowEnvironment]::ListSeparator) } 
                if (-Not([string]::IsNullOrEmpty($s_ServerBizTalk)))       { $E.ServerBizTalk       = $s_ServerBizTalk.Split([ArrowEnvironment]::ListSeparator) }
                <##>
                # HVR Values
                $E.IsHVRConfigured = $false 
                if (($null -ne $_.HVRConfig)            -And ($_.HVRConfig -ne ''))            { $E.HVRConfig             = $_.HVRConfig; $E.IsHVRConfigured = $true }
                if (($null -ne $_.HVRChannel)           -And ($_.HVRChannel -ne ''))           { $E.HVRChannel            = $_.HVRChannel }
                if (($null -ne $E.HVRConfig)            -And ($null -eq $E.HVRChannel))        { $E.HVRConfig = 'NoChannelSpecified';  $E.IsHVRConfigured = $false}

                # Secondary values                
                if (($null -ne $_.EnvType)                    -And ($_.EnvType -ne ''))                    { $E.EnvType                    = $_.EnvType }
                if (($null -ne $_.EnvPlatformType)            -And ($_.EnvPlatformType -ne ''))            { $E.Platform                   = $_.EnvPlatformType }
                if (($null -ne $_.EnvEndOfLifeDate)           -And ($_.EnvEndOfLifeDate -ne ''))           { $E.Lifecycle                  = $_.EnvEndOfLifeDate }
                if (($null -ne $_.EnvOwnerPrimaryID)          -And ($_.EnvOwnerPrimaryID -ne ''))          { $E.OwnerPrimaryID             = $_.EnvOwnerPrimaryID }
                if (($null -ne $_.EnvOwnerPrimaryName)        -And ($_.EnvOwnerPrimaryName -ne ''))        { $E.OwnerPrimaryName           = $_.EnvOwnerPrimaryName }
                if (($null -ne $_.EnvOwnerPrimaryEmail)       -And ($_.EnvOwnerPrimaryEmail -ne ''))       { $E.OwnerPrimaryEmail          = $_.EnvOwnerPrimaryEmail }
                if (($null -ne $_.EnvOwnerSecondaryID)        -And ($_.EnvOwnerSecondaryID -ne ''))        { $E.OwnerSecondaryID           = $_.EnvOwnerSecondaryID }
                if (($null -ne $_.EnvOwnerSecondaryName)      -And ($_.EnvOwnerSecondaryName -ne ''))      { $E.OwnerSecondaryName         = $_.EnvOwnerSecondaryName }
                if (($null -ne $_.EnvOwnerSecondaryEmail)     -And ($_.EnvOwnerSecondaryEmail -ne ''))     { $E.OwnerSecondaryEmail        = $_.EnvOwnerSecondaryEmail }
                if (($null -ne $_.EnvApproverID)              -And ($_.EnvApproverID -ne ''))              { $E.ApproverID                 = $_.EnvApproverID }
                if (($null -ne $_.EnvApproverName)            -And ($_.EnvApproverName -ne ''))            { $E.ApproverName               = $_.EnvApproverName }
                if (($null -ne $_.EnvApproverEmail)           -And ($_.EnvApproverEmail -ne ''))           { $E.ApproverEmail              = $_.EnvApproverEmail }
                if (($null -ne $_.EnvCreationDate)            -And ($_.EnvCreationDate -ne ''))            { $E.EnvCreated                 = $_.EnvCreationDate }
                if (($null -ne $_.EnvBranch)                  -And ($_.EnvBranch -ne ''))                  { $E.EnvTFSBranch               = $_.EnvBranch }
                if (($null -ne $_.EnvAccessType)              -And ($_.EnvAccessType -ne ''))              { $E.EnvAccessType              = $_.EnvAccessType }
                if (($null -ne $_.AXVersion)                  -And ($_.AXVersion -ne ''))                  { $E.EnvAXVersion               = $_.AXVersion }
                if (($null -ne $_.TeamsChannelName)           -And ($_.TeamsChannelName -ne ''))           { $E.EnvTeamsChannelName        = $_.TeamsChannelName }
                if (($null -ne $_.ActiveDirectoryAccessGroup) -And ($_.ActiveDirectoryAccessGroup -ne '')) { $E.ActiveDirectoryAccessGroup = $_.ActiveDirectoryAccessGroup }
                if (($null -ne $_.DMZ) -And ($_.DMZ -ne '')) { 
                    $s = $_.DMZ
                    if ($s.ToUpper() -eq 'TRUE') { $E.dmz = $true }
                    elseif ($s.ToUpper() -eq 'FALSE') { $E.dmz = $false }
                    else { $errorList += "Environment [$($E.Name)]. Wrong value for property 'DMZ' + $s" }
                } 
                if (($null -ne $_.LockDataRefresh) -And ($_.LockDataRefresh -ne '')) { 
                    $s = $_.LockDataRefresh
                    if ($s.ToUpper() -eq 'TRUE') { $E.LockDataRefresh = $true }
                    elseif ($s.ToUpper() -eq 'FALSE') { $E.LockDataRefresh = $false }
                    else { $errorList += "Environment [$($E.Name)]. Wrong value for property 'LockDataRefresh' + $s" }
                } 
                if (($null -ne $_.LockCodeRefresh) -And ($_.LockCodeRefresh -ne '')) { 
                    $s = $_.LockCodeRefresh
                    if ($s.ToUpper() -eq 'TRUE') { $E.LockCodeRefresh = $true }
                    elseif ($s.ToUpper() -eq 'FALSE') { $E.LockCodeRefresh = $false }
                    else { $errorList += "Environment [$($E.Name)]. Wrong value for property 'LockCodeRefresh' + $s" }
                }         
                if (($null -ne $_.User_AOS)                   -And ($_.User_AOS -ne ''))                   { $E.User_AOS                   = $_.User_AOS }
                if (($null -ne $_.User_BCP)                   -And ($_.User_BCP -ne ''))                   { $E.User_BCP                   = $_.User_BCP }
                if (($null -ne $_.DailyDeploymentsFrom)       -And ($_.DailyDeploymentsFrom -ne ''))       { $E.DailyDeploymentsFrom       = $_.DailyDeploymentsFrom }                
                if (-Not([string]::IsNullOrEmpty($s_ClusteredWith)))                                       { $E.ClusteredWith              = $s_ClusteredWith.Split([ArrowEnvironment]::ListSeparator) }
                if (($null -ne $_.BatchThreadCount)    -And ($_.BatchThreadCount -ne '')) 
                    { 
                        $s = $_.BatchThreadCount
                        try {
                            $E.BatchThreadCount = [int]$s
                        }
                        catch {
                            $errorList += 'Error reading xml values. Environment [' + $($E.Name) + ']. BatchThreadCount value is not an integer: [' + $s + ']'
                        }
                    }

                # Integrations
                if (($null -ne $_.IntegrationFastPath) -And ($_.IntegrationFastPath -ne '')) { 
                    $s = $_.IntegrationFastPath
                    if ($s.ToUpper() -eq 'TRUE') { $E.FastPath = $true }
                    elseif ($s.ToUpper() -eq 'FALSE') { $E.FastPath = $false }
                    else { $errorList += "Environment [$($E.Name)]. Wrong value for property 'IntegrationFastPath' + $s" }
                } 
                if (($null -ne $_.SqlReplication) -And ($_.SqlReplication -ne '')) { 
                    $s = $_.SqlReplication
                    if ($s.ToUpper() -eq 'TRUE') { $E.SqlReplication = $true }
                    elseif ($s.ToUpper() -eq 'FALSE') { $E.SqlReplication = $false }
                    else { $errorList += "Environment [$($E.Name)]. Wrong value for property 'SqlReplication' + $s" }
                } 
                if (($null -ne $_.TrustSQLCertificate) -And ($_.TrustSQLCertificate -ne '')) { 
                    $s = $_.TrustSQLCertificate
                    if ($s.ToUpper() -eq 'TRUE') { $E.TrustSQLCertificate = $true }
                    else { $E.TrustSQLCertificate = $false }
#                    elseif ($s.ToUpper() -eq 'FALSE') { $E.TrustSQLCertificate = $false }
#                    else { $errorList += "Environment [$($E.Name)]. Wrong value for property 'SqlReplication' + $s" }
                } 
                if (($null -ne $_.LegacyReplicationModule) -And ($_.LegacyReplicationModule -ne '')) { 
                    $s = $_.LegacyReplicationModule
                    if ($s.ToUpper() -eq 'TRUE') { $E.LegacyReplicationModule = $true }
                    elseif ($s.ToUpper() -eq 'FALSE') { $E.LegacyReplicationModule = $false }
                    else { $errorList += "Environment [$($E.Name)]. Wrong value for property 'LegacyReplicationModule' + $s" }
                } 
                if (($null -ne $_.IntegrationV1) -And ($_.IntegrationV1 -ne '')) { 
                    $s = $_.IntegrationV1
                    if ($s.ToUpper() -eq 'TRUE') { $E.V1 = $true }
                    elseif ($s.ToUpper() -eq 'FALSE') { $E.V1 = $false }
                    else { $errorList += "Environment [$($E.Name)]. Wrong value for property 'IntegrationV1' + $s" }
                } 

                # Process values
                if (-Not($null -eq $E.AOS )                 -And -Not($E.AOS -is [array]))                 { $E.AOS                  = @($E.AOS) }
                if (-Not($null -eq $E.BAT )                 -And -Not($E.BAT -is [array]))                 { $E.BAT                  = @($E.BAT) }
                if (-Not($null -eq $E.SRS )                 -And -Not($E.SRS -is [array]))                 { $E.SRS                  = @($E.SRS) }
                if (-Not($null -eq $E.LBS )                 -And -Not($E.LBS -is [array]))                 { $E.LBS                  = @($E.LBS) }
                if (-Not($null -eq $E.INT )                 -And -Not($E.INT -is [array]))                 { $E.INT                  = @($E.INT) }
                if (-Not($null -eq $E.BATSpecialConfigRaw ) -And -Not($E.BATSpecialConfigRaw -is [array])) { $E.BATSpecialConfigRaw  = @($E.BATSpecialConfigRaw) }
                if (-Not($null -eq $E.JumpBox )             -And -Not($E.JumpBox -is [array]))             { $E.JumpBox              = @($E.JumpBox) }
                if (-Not($null -eq $E.ServerAtlas )         -And -Not($E.ServerAtlas -is [array]))         { $E.ServerAtlas          = @($E.ServerAtlas) }
                if (-Not($null -eq $E.ServerBOG )           -And -Not($E.ServerBOG -is [array]))           { $E.ServerBOG            = @($E.ServerBOG) }
                if (-Not($null -eq $E.ServerFiles )         -And -Not($E.ServerFiles -is [array]))         { $E.ServerFiles          = @($E.ServerFiles) }
                if (-Not($null -eq $E.ServerBizTalk )       -And -Not($E.ServerBizTalk -is [array]))       { $E.ServerBizTalk        = @($E.ServerBizTalk) }
                if (-Not($null -eq $E.ClusteredWith )       -And -Not($E.ClusteredWith -is [array]))       { $E.ClusteredWith        = @($E.ClusteredWith) }
                
                if ([string]::IsNullOrEmpty($E.EnvType))                                                   { $E.EnvType              = "AX" }
                if ([string]::IsNullOrEmpty($E.DailyDeploymentsFrom))                                      { $E.DailyDeploymentsFrom = "none" }

                if ($null -ne $E.Lifecycle) {
                    try {
                        $E.LifecycleDate = [DateTime]$E.Lifecycle
                    }
                    catch {
                        $errorList += "Environment" + $E.Name + ": Property 'EnvEndOfLifeDate' contains invalid date format. Actual: " + $E.Lifecycle
                    }
                }
                if ($null -ne $E.EnvCreated) {
                    try {
                        $E.EnvCreatedDate = [DateTime]$E.EnvCreated
                    }
                    catch {
                        $errorList += "Environment" + $E.Name + ": Property 'EnvCreated' contains invalid date format. Actual: " + $E.EnvCreated
                    }
                }
                if ($null -ne $E.ClusteredWith) {
                    try {
                        foreach ($cItem in $E.ClusteredWith) {
                            if ($cItem -eq $E.Name) {
                                $errorList += "Environment" + $E.Name + ": Property 'ClusteredWith' - cannot be clustered with itself"
                            }
                        }
                    }
                    catch {
                        Write-Host "WARNING: Error checking 'ClusteredWith' property for environment '$($E.Name)': $_"
                    }
                }

                # Validate
                [string]$envNameStr = $E.Name
                if ($envNameStr -eq '' ) {
                    $errorList += "Property 'EnvShortName' must not be empty"
                } 

                if ($environmentNames -match $E.Name) {
                    $errorList += 'Duplicate environment name found: ' + $E.Name
                }
                else {
                    $environmentNames += $E.Name
                }

                $global:envClassList += $E
            }

            # ---------------------------------------------------------------------------------------
            # Get the data from Strapi - Configurations
            # ---------------------------------------------------------------------------------------
            $link = $global:StrapiConfigUrl + "?pagination[pageSize]=1000"
            try {
                $response = Invoke-RestMethod $link -TimeoutSec 15
                $EnvStrapi = Invoke-Expression "`$response.$($Global:StrapiResultLocation)"
            }
            catch {
                Write-Host "Strapi - Configurations" -ForegroundColor Red
                Write-Host "ERROR: Cannot read data from link: $link" -ForegroundColor Red
                throw $_
            }

            # Process all items from Strapi
            $EnvStrapi | ForEach-Object {
                $E = $null
                if (($null -ne $_.EnvShortName) -And ($_.EnvShortName -ne '')) { 
                    $E = Find-EcsStrEnvironmentClass -envShortName_arg $_.EnvShortName
                }
                else {
                    $errorList += "Environment configuration has empty EnvShortName field value. ID = " + $_.ID
                }

                if (($null -ne $E) -And ($null -ne $_.EnvShortName)) {
                    # Add values to the class
                    if (($null -ne $_.ReplicationPublication)    -And ($_.ReplicationPublication -ne ''))    { $E.ReplicationPublication        = $_.ReplicationPublication }
                    if (($null -ne $_.ReplicationSubscriber)     -And ($_.ReplicationSubscriber -ne ''))     { $E.ReplicationSubscriber         = $_.ReplicationSubscriber }
                    if (($null -ne $_.ReplicationDestination)    -And ($_.ReplicationDestination -ne ''))    { $E.ReplicationDestinationDB      = $_.ReplicationDestination }
                    if (($null -ne $_.ReplicationInstance)       -And ($_.ReplicationInstance -ne ''))       { $E.ReplicationInstance           = $_.ReplicationInstance }                    
        
                    if (($null -ne $_.SRSServerInstance)         -And ($_.SRSServerInstance -ne ''))         { $E.ReportsServerInstance         = $_.SRSServerInstance }
                    if (($null -ne $_.SRSServerURLSuffix)        -And ($_.SRSServerURLSuffix -ne ''))        { $E.ReportsServerURLSuffix        = $_.SRSServerURLSuffix }
                    if (($null -ne $_.SRSReportManagerURLSuffix) -And ($_.SRSReportManagerURLSuffix -ne '')) { $E.ReportsReportManagerURLSuffix = $_.SRSReportManagerURLSuffix }
                    if (($null -ne $_.SRSReportServiceSuffix)    -And ($_.SRSReportServiceSuffix -ne ''))    { $E.ReportsReportServiceSuffix    = $_.SRSReportServiceSuffix }
                    
                    if (($null -ne $_.DIXFFolder)                -And ($_.DIXFFolder -ne ''))                { $E.DIXFFolder                    = $_.DIXFFolder }
        
                    if (($null -ne $_.ClientConfigUSR)           -And ($_.ClientConfigUSR -ne ''))           { $E.ConfigurationClientUSR        = $_.ClientConfigUSR }
                    if (($null -ne $_.ClientConfigCUS)           -And ($_.ClientConfigCUS -ne ''))           { $E.ConfigurationClientCUS        = $_.ClientConfigCUS }
                    if (($null -ne $_.EnvConfigAOSBufferSize)    -And ($_.EnvConfigAOSBufferSize -ne '')) 
                    { 
                        $s = $_.EnvConfigAOSBufferSize
                        try {
                            $E.ConfigurationAOSBufferSize = [int]$s
                        }
                        catch {
                            $errorList += 'Error reading xml values. Environment [' + $($E.Name) + ']. AOSBufferSize value is not an integer: [' + $s + ']'
                        }
                    }
                        
                    if (($null -ne $_.CommonReconfigureScript) -And ($_.CommonReconfigureScript -ne ''))  { $E.CommonScriptsReconfigure    = $_.CommonReconfigureScript }
                    if (($null -ne $_.ReconfigureScript) -And ($_.ReconfigureScript -ne ''))              { $E.SpecificScriptsReconfigure  = $_.ReconfigureScript.Split([ArrowEnvironment]::ListSeparator) }

                    if (($null -ne $_.CommonDeploymentScript) -And ($_.CommonDeploymentScript -ne ''))    { $E.CommonScriptsDeployment     = $_.CommonDeploymentScript }
                    if (($null -ne $_.DeploymentScript) -And ($_.DeploymentScript -ne ''))                { $E.SpecificScriptsDeployment   = $_.DeploymentScript.Split([ArrowEnvironment]::ListSeparator) }
                
                    if (($null -ne $_.Development) -And ($_.Development -ne '')) { 
                        $s = $_.Development
                        if ($s.ToUpper() -eq 'TRUE') { $E.Development = $true }
                        elseif ($s.ToUpper() -eq 'FALSE') { $E.Development = $false }
                        else { $errorList += "Environment [$($E.Name)]. Wrong value for property 'Development' + $s" }
                    } 
                    if (($null -ne $_.TFSMapping)          -And ($_.TFSMapping -ne ''))          { $E.TFSMapping     = $_.TFSMapping }
            
                    # Process values
                    if (-Not($null -eq $E.SpecificScriptsReconfigure) -And -Not($E.SpecificScriptsReconfigure -is [array])) { $E.SpecificScriptsReconfigure = @($E.SpecificScriptsReconfigure) }
                    if (-Not($null -eq $E.SpecificScriptsDeployment)  -And -Not($E.SpecificScriptsDeployment -is [array]))  { $E.SpecificScriptsDeployment  = @($E.SpecificScriptsDeployment) }
                    if (-Not($null -eq $E.TFSMapping )                -And -Not($E.TFSMapping -is [array]))                 { $E.TFSMapping = @($E.TFSMapping) }
                }
                else {
                    $infoMsgList += "[INFO] Environment '" + $_.EnvShortName + "' configuration skipped: Not a BC/NAV environment"
                }            
            }

            # ---------------------------------------------------------------------------------------
            # Get the data from Strapi - Access
            # ---------------------------------------------------------------------------------------
            $link = $Global:StrapiAccessUrl + "?pagination[pageSize]=1000"
            try {
                $response = Invoke-RestMethod $link -TimeoutSec 15
                $EnvStrapi = Invoke-Expression "`$response.$($Global:StrapiResultLocation)"
            }
            catch {
                Write-Host "Strapi - Access" -ForegroundColor Red
                Write-Host "ERROR: Cannot read data from link: $link" -ForegroundColor Red
                throw $_
            }

            # Process all items from Strapi
            $EnvStrapi | ForEach-Object {
                $E = $null
                if (($null -ne $_.EnvShortName) -And ($_.EnvShortName -ne '')) { 
                    $E = Find-EcsStrEnvironmentClass -envShortName_arg $_.EnvShortName
                }
                else {
                    $errorList += "Environment access has empty EnvShortName field value. ID = " + $_.ID
                }

                if (($null -ne $E) -And ($null -ne $_.EnvShortName)) {
                    # Add values to the class
                    if (($null -ne $_.KeepUserAccessAfterDataRestore) -And ($_.KeepUserAccessAfterDataRestore -ne '')) { 
                        $s = $_.KeepUserAccessAfterDataRestore
                        if ($s.ToUpper() -eq 'TRUE')      { $E.KeepUserAccessAfterDataRestore = $true }
                        elseif ($s.ToUpper() -eq 'FALSE') { $E.KeepUserAccessAfterDataRestore = $false }
                        else { $errorList += "Environment [$E.Name]. Wrong value for property 'KeepUserAccessAfterDataRestore' + $s" }
                    }
                    else {
                        $E.KeepUserAccessAfterDataRestore = $false
                    }
                    if (($null -ne $_.KeepSVCParametersAfterDataRestore) -And ($_.KeepSVCParametersAfterDataRestore -ne '')) { 
                        $s = $_.KeepSVCParametersAfterDataRestore
                        if ($s.ToUpper() -eq 'TRUE')      { $E.KeepSVCParametersAfterDataRestore = $true }
                        elseif ($s.ToUpper() -eq 'FALSE') { $E.KeepSVCParametersAfterDataRestore = $false }
                        else { $errorList += "Environment [$E.Name]. Wrong value for property 'KeepSVCParametersAfterDataRestore' + $s" }
                    }
                    else {
                        $E.KeepSVCParametersAfterDataRestore = $false
                    }
                    if (($null -ne $_.KeepProdUsersAfterDataRestore) -And ($_.KeepProdUsersAfterDataRestore -ne '')) { 
                        $s = $_.KeepProdUsersAfterDataRestore
                        if ($s.ToUpper() -eq 'TRUE')      { $E.KeepProdUsersAfterDataRestore = $true }
                        elseif ($s.ToUpper() -eq 'FALSE') { $E.KeepProdUsersAfterDataRestore = $false }
                        else { $errorList += "Environment [$E.Name]. Wrong value for property 'KeepProdUsersAfterDataRestore' + $s" }
                    }
                    else {
                        $E.KeepProdUsersAfterDataRestore = $false
                    }

                    if (($null -ne $_.SysAdmin)          -And ($_.SysAdmin -ne ''))          { $E.AccessSysAdmin     = EcsStrInternal-ReadAccessValue -accessValue_arg $_.SysAdmin }
                    if (($null -ne $_.SysAdminTemporary) -And ($_.SysAdminTemporary -ne '')) { $E.AccessSysAdminTemp = EcsStrInternal-ReadAccessValue -accessValue_arg $_.SysAdminTemporary }
                    if (($null -ne $_.SecAdmin)          -And ($_.SecAdmin -ne ''))          { $E.AccessSecAdmin     = EcsStrInternal-ReadAccessValue -accessValue_arg $_.SecAdmin }
                    if (($null -ne $_.OtherRoles)        -And ($_.OtherRoles -ne ''))        { $E.AccessOtherRoles   = EcsStrInternal-ReadAccessValue -accessValue_arg $_.OtherRoles -otherRoles }

                    # Process values
                    if (-Not($null -eq $E.AccessSysAdmin )     -And -Not($E.AccessSysAdmin -is [array]))     { $E.AccessSysAdmin = @($E.AccessSysAdmin) }
                    if (-Not($null -eq $E.AccessSysAdminTemp ) -And -Not($E.AccessSysAdminTemp -is [array])) { $E.AccessSysAdminTemp = @($E.AccessSysAdminTemp) }
                    if (-Not($null -eq $E.AccessSecAdmin )     -And -Not($E.AccessSecAdmin -is [array]))     { $E.AccessSecAdmin = @($E.AccessSecAdmin) }
                    if (-Not($null -eq $E.AccessOtherRoles )   -And -Not($E.AccessOtherRoles -is [array]))   { $E.AccessOtherRoles = @($E.AccessOtherRoles) }
                }
                else {
                    $infoMsgList += "[INFO] Environment '" + $_.EnvShortName + "' access skipped: Not a BC/NAV environment"                
                }            
            }
            
            # ---------------------------------------------------------------------------------------
            # Get the data from Strapi - BC environment specific fields
            # ---------------------------------------------------------------------------------------
            $link = $Global:StrapiBCDetailsUrl `
                + "?pagination[pageSize]=1000" `
                + "&populate[ServersWithServicesToRestart][populate][services]=*" `
                + "&populate[DevUserList][populate][UserID]=*"
            try {
                $response = Invoke-RestMethod $link -TimeoutSec 15
                $EnvStrapi = Invoke-Expression "`$response.$($Global:StrapiResultLocation)"
            }
            catch {
                Write-Host "Strapi - Access" -ForegroundColor Red
                Write-Host "ERROR: Cannot read data from link: $link" -ForegroundColor Red
                throw $_
            }

            # Process all items from Strapi
            $EnvStrapi | ForEach-Object {
                $E = $null
                if (($null -ne $_.EnvShortName) -And ($_.EnvShortName -ne '')) { 
                    $E = Find-EcsStrEnvironmentClass -envShortName_arg $_.EnvShortName
                }
                else {
                    $errorList += "Environment access has empty EnvShortName field value. ID = " + $_.ID
                }

                if (($null -ne $E) -And ($null -ne $_.EnvShortName)) {
                    # Add values to the class
                    if (($null -ne $_.EnvShortName)        -And ($_.EnvShortName -ne '')) { $E.Name = $_.EnvShortName }
                    if (($null -ne $_.Description) -And ($_.Description -ne ''))   { $E.Description = $_.Description }
                    $E.DatabaseName           = $_.DatabaseName.replace(" ","").Trim()
                    $E.DatabaseServerName     = $_.DatabaseServerName.replace(" ","").Trim()
                    $E.TargetBCServerName     = $_.TargetBCServerName.replace(" ","").Trim()
                    $E.TargetBCServerInstance = $_.TargetBCServerInstance.replace(" ","").Trim()
                    if (($null -ne $_.ObjectCodeToImport) -And ($_.ObjectCodeToImport -ne '')) { $E.ObjectCodeToImport     = $_.ObjectCodeToImport.replace(" ","").Trim() }
                    if (($null -ne $_.ObjectCodeAfterImport) -And ($_.ObjectCodeAfterImport -ne '')) { $E.ObjectCodeAfterImport     = $_.ObjectCodeAfterImport.replace(" ","").Trim() }
                    if (($null -ne $_.Region) -And ($_.Region -ne '')) { $E.Region = $_.Region }
                    $E.CompanyNameToOperate   = $_.CompanyNameToOperate
                    $E.ManagementPort         = [int]$_.ManagementPort

                    # build nested array for servers with services to restart
                    $E.ServersWithServicesToRestart = @()
                    foreach ($srv in $_.ServersWithServicesToRestart) {
                        # Safely extract services into an array, even if $srv.services is $null
                        $svcNames = @()
                        if ($srv.services) {
                            $svcNames = $srv.services | ForEach-Object { $_.serviceName }
                        }

                        $E.ServersWithServicesToRestart += [BCServerServiceRestart]@{
                            ServerName = $srv.ServerName
                            Services   = $svcNames
                        }
                    }
                    # build dev users' array
                    $E.DevUserList = @()
                    if ($_.DevUserList) {
                        foreach ($u in $_.DevUserList) {
                            $E.DevUserList += $u.userId.Trim()
                        }
                    }
                }
                else {
                    $infoMsgList += "[INFO] Environment '" + $_.EnvShortName + "' access skipped: Not a BC/NAV environment"                
                }       
            }

            # Validate
            [string]$envNameStr = $E.Name
            if ($envNameStr -eq '' ) {
                $errorList += "Property 'EnvShortName' must not be empty"
            } else {
                if (($null -eq $E.DatabaseServerName) -Or ($E.DatabaseServerName -eq '' )) {
                    $errorList += "Environment $envNameStr : Property 'DatabaseServerName' must not be empty"
                }
                if (($null -eq $E.DatabaseName) -Or ($E.DatabaseName -eq '' )) {
                    $errorList += "Environment $envNameStr : Property 'DatabaseName' must not be empty"
                }
            }


            $dataLoaded = $true

        }
        catch {
            Write-Host "Unable to retreive data from Strapi!" -ForegroundColor Red
            Write-Host "ERROR: $_"

            if ($doNotReadFromBackup) {
                Write-Host "Do not load from backup parameter was specified, the process will be stopped"
                throw $_
            }
        }

        if (!$dataLoaded) {
            Write-Host " "
            Write-Host "Data was not loaded from Strapi, trying to load from backups"
            Get-EcsStrEnvironmentClassFromBackup
        }

        # Show/Throw errors if any
        $s = ''
        if ($errorList.Length -gt 0) {
            foreach ($line in $errorList) {
                $s += " - " + $line + "`n"
            }
            if ($failInCaseOfDataErrors) {
                throw $s
            }
            else {
                Write-Host " "
                Write-Host "*********************************************************" -ForegroundColor Yellow
                Write-Host "Data errors found:" -ForegroundColor Yellow
                Write-Host "------------------" -ForegroundColor Yellow
                Write-Host "$s" -ForegroundColor Yellow
                Write-Host "*********************************************************" -ForegroundColor Yellow
                Write-Host " "
            }
        }

        # Show info messages if any
        $s = ''
        if ($infoMsgList.Length -gt 0) {
            foreach ($line in $infoMsgList) {
                $s += " - " + $line + "`n"
            }
            if ($failInCaseOfDataErrors) {
                throw $s
            }
            else {
                Write-Host " "
                Write-Host "*********************************************************" -ForegroundColor Yellow
                Write-Host "Information:" -ForegroundColor Yellow
                Write-Host "------------------" -ForegroundColor Yellow
                Write-Host "$s" -ForegroundColor Yellow
                Write-Host "*********************************************************" -ForegroundColor Yellow
                Write-Host " "
            }
        }


        if (!$noOutput) {
            Write-Host 'Environment records found:' $global:envClassList.Length
        }

        # Show elapsed time
        $elapsedTime = $(get-date) - $StartTime
        $totalTime = "{0:HH:mm:ss.fff}" -f ([datetime]$elapsedTime.Ticks)
        if (!$noOutput) {
            Write-Host 'Time elapsed:' $totalTime.ToString()
        }
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
        if (!$noOutput) {
            Write-Host $EndMessage
        }
        Write-PriWinEvent -LogName $GlobalEventsLog -LogSource "$LogSource" -EventID 2000 -Message "$EndMessage`r`n$MyParams" -EntryType $EntryType; Start-Sleep 1
        Pop-Location
    }
    <#
    .SYNOPSIS
    .DESCRIPTION
    .EXAMPLE
    .EXAMPLE
    .LINK
#>
}
<## >
Get-EcsStrDataAsClass
<## >
Write-Host '> List length:' $global:envClassList.Length
if ($global:envClassList.Length -gt 0) {
    [ArrowEnvironment]$E = Find-EcsStrEnvironmentClass -envShortName_arg "PAT"
    if ($null -ne $E) {
        Write-Host '>--------------------------'
        Write-Host $E.ToString()
        Write-Host '>--------------------------'
    }
}
<##>