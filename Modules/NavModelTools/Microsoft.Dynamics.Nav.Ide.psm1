param ([string] $NavIde)

# If $NavIde is not provided try to find finsql in:
#    1) the current folder, or
#    2) RTC's installation folder.
if (-not $NavIde)
{
    if (Test-Path (Join-Path $PSScriptRoot finsql.exe))
    {
        $NavIde = (Join-Path $PSScriptRoot finsql.exe)
    }
    else
    {
        if ([Environment]::Is64BitProcess)
        {
            $RtcKey = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Microsoft Dynamics NAV\140\RoleTailored Client'
        }
        else
        {
            $RtcKey = 'HKLM:\SOFTWARE\Microsoft\Microsoft Dynamics NAV\140\RoleTailored Client'
        }

        if (Test-Path $RtcKey)
        {
            $NavIde = (Join-Path (Get-ItemProperty $RtcKey).Path finsql.exe)
        }
    }
}

if ($NavIde -and (Test-Path $NavIde))
{
	$NavClientPath = (Get-Item $NavIde).DirectoryName
}

<#
    .SYNOPSIS
    Imports Business Central application objects from a file into a database.

    .DESCRIPTION
    The Import-NAVApplicationObject function imports the objects from the specified file(s) into the specified database. When multiple files are specified, finsql is invoked for each file. For better performance the files can be joined first. However, using seperate files can be useful for analyzing import errors.

    .INPUTS
    System.String[]
    You can pipe a path to the Import-NavApplicationObject function.

    .OUTPUTS
    None

    .EXAMPLE
    Import-NAVApplicationObject MyAppSrc.txt MyApp
    This command imports all application objects in MyAppSrc.txt into the MyApp database.

    .EXAMPLE
    Import-NAVApplicationObject MyAppSrc.txt -DatabaseName MyApp
    This command imports all application objects in MyAppSrc.txt into the MyApp database.

    .EXAMPLE
    Get-ChildItem MyAppSrc | Import-NAVApplicationObject -DatabaseName MyApp
    This commands imports all objects in all files in the MyAppSrc folder into the MyApp database. The files are imported one by one.

    .EXAMPLE
    Get-ChildItem MyAppSrc | Join-NAVApplicationObject -Destination .\MyAppSrc.txt -PassThru | Import-NAVApplicationObject -Database MyApp
    This commands joins all objects in all files in the MyAppSrc folder into a single file and then imports them in the MyApp database.
#>
function Import-NAVApplicationObject
{
    [CmdletBinding(DefaultParameterSetName="All", SupportsShouldProcess=$true, ConfirmImpact='High')]
    Param(
        # Specifies one or more files to import.
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('PSPath')]
        [string[]] $Path,

        # Specifies the name of the database into which you want to import.
        [Parameter(Mandatory=$true, Position=1)]
        [string] $DatabaseName,

        # Specifies the name of the SQL server instance to which the database you want to import into is attached. The default value is the default instance on the local host (.).
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseServer = '.',

        # Specifies the log folder.
        [ValidateNotNullOrEmpty()]
        [string] $LogPath = "$Env:TEMP\NavIde\$([GUID]::NewGuid().GUID)",

        # Specifies the import action. The default value is 'Default'.
        [ValidateSet('Default','Overwrite','Skip')] [string] $ImportAction = 'Default',

        # Specifies the schema synchronization behaviour. The default value is 'Yes'.
        [ValidateSet('Yes','No','Force')] [string] $SynchronizeSchemaChanges = 'Yes',

        # The user name to use to authenticate to the database. The user name must exist in the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Username,

        # The password to use with the username parameter to authenticate to the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Password,

        # Specifies the name of the server that hosts the Business Central Server instance, such as MyServer.
        [ValidateNotNullOrEmpty()]
        [string] $NavServerName,

        # Specifies the Business Central Server instance that is being used.The default value is DynamicsNAV90.
        [ValidateNotNullOrEmpty()]
        [string] $NavServerInstance = "DynamicsNAV90",

        # Specifies the port on the Business Central Server server that the Business Central Windows PowerShell cmdlets access. The default value is 7045.
        [ValidateNotNullOrEmpty()]
        [int16]  $NavServerManagementPort = 7045,

        # Specifies whether the build of the Search Index needs to be suppressed.
        [Switch]  $SuppressBuildSearchIndex,

        # Parameter to toggle on/off the elevation check when upgrading database. Default value is No (check on).
        [ValidateSet('Yes','No','1','0')] 
        [string] $SuppressElevationCheck = '0')

    PROCESS
    {
        if ($Path.Count -eq 1)
        {
            #NV8 - S
            # Write-Output("Path: $Path")

            # # Get invalid path characters
            # $invalidChars = [IO.Path]::GetInvalidPathChars()

            # # Convert path to character array
            # $pathChars = $Path.ToCharArray()

            # # Check if the path contains any invalid characters
            # if ($Path.IndexOfAny($invalidChars) -ne -1) {
            #     Write-Host "The path contains invalid characters." -ForegroundColor Red

            #     # Output the exact invalid characters (including Unicode values)
            #     $invalidFound = $pathChars | Where-Object { $invalidChars -contains $_ }
            #     if ($invalidFound) {
            #         $invalidFound | ForEach-Object {
            #             Write-Host "Invalid character: $_ (Unicode: $([int][char]$_))" -ForegroundColor Yellow
            #         }
            #     } else {
            #         Write-Host "No visible invalid characters found, but the path is still invalid." -ForegroundColor Magenta
            #     }
            # } else {
            #     Write-Host "The path is valid." -ForegroundColor Green
            # }
            #NV8 - E

            $Path = (Get-Item $Path).FullName
        }
        #NV8 - S
        #Write-Output("Path 2: $Path")
        #NV8- E
        if ($PSCmdlet.ShouldProcess(
            "Import application objects from $Path into the $DatabaseName database.",
            "Import application objects from $Path into the $DatabaseName database. If you continue, you may lose data in fields that are removed or changed in the imported file.",
            'Confirm'))
        {
            $navServerInfo = GetNavServerInfo $NavServerName $NavServerInstance $NavServerManagementPort

            foreach ($file in $Path)
            {
                # Log file name is based on the name of the imported file.
                $logFile = "$LogPath\$((Get-Item $file).BaseName).log"
                $command = "Command=ImportObjects`,ImportAction=$ImportAction`,SynchronizeSchemaChanges=$SynchronizeSchemaChanges`,File=`"$file`""
                if ($SuppressBuildSearchIndex)
                {
                    $command += ",SuppressBuildSearchIndex=Yes"
                }

                try
                {
                    RunNavIdeCommand -Command $command `
                                     -DatabaseServer $DatabaseServer `
                                     -DatabaseName $DatabaseName `
                                     -NTAuthentication:($Username -eq $null) `
                                     -Username $Username `
                                     -Password $Password `
                                     -NavServerInfo $navServerInfo `
                                     -LogFile $logFile `
                                     -ErrText "Error while importing $file" `
                                     -Verbose:$VerbosePreference `
                                     -SuppressElevationCheck $SuppressElevationCheck
                }
                catch
                {
                    Write-Error $_
                }
            }
        }
    }
}

function Cust-Import-NAVApplicationObject #Customized function omitc ISE  Interactive mode
{
    [CmdletBinding(DefaultParameterSetName="All", SupportsShouldProcess=$true, ConfirmImpact='High')]
    Param(
        # Specifies one or more files to import.
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('PSPath')]
        [string[]] $Path,

        # Specifies the name of the database into which you want to import.
        [Parameter(Mandatory=$true, Position=1)]
        [string] $DatabaseName,

        # Specifies the name of the SQL server instance to which the database you want to import into is attached. The default value is the default instance on the local host (.).
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseServer = '.',

        # Specifies the log folder.
        [ValidateNotNullOrEmpty()]
        [string] $LogPath = "$Env:TEMP\NavIde\$([GUID]::NewGuid().GUID)",

        # Specifies the import action. The default value is 'Default'.
        [ValidateSet('Default','Overwrite','Skip')] [string] $ImportAction = 'Default',

        # Specifies the schema synchronization behaviour. The default value is 'Yes'.
        [ValidateSet('Yes','No','Force')] [string] $SynchronizeSchemaChanges = 'Yes',

        # The user name to use to authenticate to the database. The user name must exist in the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Username,

        # The password to use with the username parameter to authenticate to the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Password,

        # Specifies the name of the server that hosts the Business Central Server instance, such as MyServer.
        [ValidateNotNullOrEmpty()]
        [string] $NavServerName,

        # Specifies the Business Central Server instance that is being used.The default value is DynamicsNAV90.
        [ValidateNotNullOrEmpty()]
        [string] $NavServerInstance = "DynamicsNAV90",

        # Specifies the port on the Business Central Server server that the Business Central Windows PowerShell cmdlets access. The default value is 7045.
        [ValidateNotNullOrEmpty()]
        [int16]  $NavServerManagementPort = 7045,

        # Specifies whether the build of the Search Index needs to be suppressed.
        [Switch]  $SuppressBuildSearchIndex,

        # Parameter to toggle on/off the elevation check when upgrading database. Default value is No (check on).
        [ValidateSet('Yes','No','1','0')] 
        [string] $SuppressElevationCheck = '0',
        [string] $NewNavIde
        )  

        PROCESS
        {
            if ($Path.Count -eq 1)
            {
                #NV8 - S
                # Write-Output("Path: $Path")
    
                # # Get invalid path characters
                # $invalidChars = [IO.Path]::GetInvalidPathChars()
    
                # # Convert path to character array
                # $pathChars = $Path.ToCharArray()
    
                # # Check if the path contains any invalid characters
                # if ($Path.IndexOfAny($invalidChars) -ne -1) {
                #     Write-Host "The path contains invalid characters." -ForegroundColor Red
    
                #     # Output the exact invalid characters (including Unicode values)
                #     $invalidFound = $pathChars | Where-Object { $invalidChars -contains $_ }
                #     if ($invalidFound) {
                #         $invalidFound | ForEach-Object {
                #             Write-Host "Invalid character: $_ (Unicode: $([int][char]$_))" -ForegroundColor Yellow
                #         }
                #     } else {
                #         Write-Host "No visible invalid characters found, but the path is still invalid." -ForegroundColor Magenta
                #     }
                # } else {
                #     Write-Host "The path is valid." -ForegroundColor Green
                # }
                #NV8 - E
    
                $Path = (Get-Item $Path).FullName
            }
            #NV8 - S
            #Write-Output("Path 2: $Path")
            #NV8- E
            # if$ (PSCmdlet.ShouldProcess(
            #     "Import application objects from $Path into the $DatabaseName database.",
            #     "Import application objects from $Path into the $DatabaseName database. If you continue, you may lose data in fields that are removed or changed in the imported file.",
            #     'Confirm'))
            # {
                $navServerInfo = GetNavServerInfo $NavServerName $NavServerInstance $NavServerManagementPort
    
                foreach ($file in $Path)
                {
                    # Log file name is based on the name of the imported file.
                    $logFile = "$LogPath\$((Get-Item $file).BaseName).log"
                    $command = "Command=ImportObjects`,ImportAction=$ImportAction`,SynchronizeSchemaChanges=$SynchronizeSchemaChanges`,File=`"$file`""
                    if ($SuppressBuildSearchIndex)
                    {
                        $command += ",SuppressBuildSearchIndex=Yes"
                    }
    
                    try
                    {
                        RunNavIdeCommand -Command $command `
                                         -DatabaseServer $DatabaseServer `
                                         -DatabaseName $DatabaseName `
                                         -NTAuthentication:($Username -eq $null) `
                                         -Username $Username `
                                         -Password $Password `
                                         -NavServerInfo $navServerInfo `
                                         -LogFile $logFile `
                                         -ErrText "Error while importing $file" `
                                         -Verbose:$VerbosePreference `
                                         -SuppressElevationCheck $SuppressElevationCheck
                    }
                    catch
                    {
                        Write-Error $_
                    }
                }
           # }
        }
    }

function GetNavServerInfo
(
    [string] $NavServerName,
    [string] $NavServerInstance,
    [int16]  $NavServerManagementPort
)
{
    $navServerInfo = ""
    if ($navServerName)
    {
        $navServerInfo = @"
`,NavServerName="$NavServerName"`,NavServerInstance="$NavServerInstance"`,NavServerManagementport=$NavServerManagementPort
"@
    }

    $navServerInfo
}

function RunNavIdeCommand
{
    [CmdletBinding()]
    Param(
    [string] $Command,
    [string] $DatabaseServer,
    [string] $DatabaseName,
    [switch] $NTAuthentication,
    [string] $Username,
    [string] $Password,
    [string] $NavServerInfo,
    [string] $LogFile,
    [string] $ErrText,
    [string] $SuppressElevationCheck)

    TestNavIde
    $logPath = (Split-Path $LogFile)

    Remove-Item "$logPath\navcommandresult.txt" -ErrorAction Ignore
    Remove-Item $logFile -ErrorAction Ignore

    $databaseInfo = @"
ServerName="$DatabaseServer"`,Database="$DatabaseName"
"@
    if ($Username)
    {
        $databaseInfo = @"
ntauthentication=No`,username="$Username"`,password="$Password"`,$databaseInfo
"@
    }

    $finSqlCommand = @"
& "$NavIde" --% $Command`,LogFile="$logFile"`,${databaseInfo}${NavServerInfo}`,SuppressElevationCheck="$SuppressElevationCheck" | Out-Null
"@

    Write-Verbose "Running command: $finSqlCommand"
    Invoke-Expression -Command  $finSqlCommand

    if (Test-Path "$logPath\navcommandresult.txt")
    {
        if (Test-Path $LogFile)
        {
            throw "${ErrorText}: $(Get-Content $LogFile -Raw)" -replace "`r[^`n]","`r`n"
        }
    }
    else
    {
        throw "${ErrorText}!"
    }
}

<#
    .SYNOPSIS
    Export Business Central application objects from a database into a file.

    .DESCRIPTION
    The Export-NAVApplicationObject function exports the objects from the specified database into the specified file. A filter can be specified to select the application objects to be exported.

    .INPUTS
    None
    You cannot pipe input to this function.

    .OUTPUTS
    System.IO.FileInfo
    An object representing the exported file.

    .EXAMPLE
    Export-NAVApplicationObject MyApp MyAppSrc.txt
    Exports all application objects from the MyApp database to MyAppSrc.txt.

    .EXAMPLE
    Export-NAVApplicationObject MyAppSrc.txt -DatabaseName MyApp
    Exports all application objects from the MyApp database to MyAppSrc.txt.

    .EXAMPLE
    Export-NAVApplicationObject MyApp COD1-10.txt -Filter 'Type=Codeunit;Id=1..10'
    Exports codeunits 1..10 from the MyApp database to COD1-10.txt

    .EXAMPLE
    Export-NAVApplicationObject COD1-10.txt -DatabaseName MyApp -Filter 'Type=Codeunit;Id=1..10'
    Exports codeunits 1..10 from the MyApp database to COD1-10.txt

    .EXAMPLE
    Export-NAVApplicationObject COD1-10.txt -DatabaseName MyApp -Filter 'Type=Codeunit;Id=1..10' | Import-NAVApplicationObject -DatabaseName MyApp2
    Copies codeunits 1..10 from the MyApp database to the MyApp2 database.

    .EXAMPLE
    Export-NAVApplicationObject MyAppSrc.txt -DatabaseName MyApp | Split-NAVApplicationObject -Destination MyAppSrc
    Exports all application objects from the MyApp database and splits into single-object files in the MyAppSrc folder.
#>
function Export-NAVApplicationObject
{
    [CmdletBinding(DefaultParameterSetName="All",SupportsShouldProcess = $true)]
    Param(
        # Specifies the name of the database from which you want to export.
        [Parameter(Mandatory=$true, Position=0)]
        [string] $DatabaseName,

        # Specifies the file to export to.
        [Parameter(Mandatory=$true, Position=1)]
        [string] $Path,

        # Specifies the name of the SQL server instance to which the database you want to import into is attached. The default value is the default instance on the local host (.).
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseServer = '.',

        # Specifies the log folder.
        [ValidateNotNullOrEmpty()]
        [string] $LogPath = "$Env:TEMP\NavIde\$([GUID]::NewGuid().GUID)",

        # Specifies the filter that selects the objects to export.
        [string] $Filter,

        # Allows the command to create a file that overwrites an existing file.
        [Switch] $Force,

        # Allows the command to skip application objects that are excluded from license, when exporting as txt.
        [Switch] $ExportTxtSkipUnlicensed,

        # Export the application object to the syntax supported by the Txt2Al converter.
        [Switch] $ExportToNewSyntax,

        # The user name to use to authenticate to the database. The user name must exist in the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Username,

        # The password to use with the username parameter to authenticate to the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Password,

        # Parameter to toggle on/off the elevation check when upgrading database. Default value is No (check on).
        [ValidateSet('Yes','No','1','0')] 
        [string] $SuppressElevationCheck = '0')

    if ($PSCmdlet.ShouldProcess(
        "Export application objects from $DatabaseName database to $Path.",
        "Export application objects from $DatabaseName database to $Path.",
        'Confirm'))
    {
        if (!$Force -and (Test-Path $Path) -and !$PSCmdlet.ShouldContinue(
            "$Path already exists. If you continue, $Path will be overwritten.",
            'Confirm'))
        {
            Write-Error "$Path already exists."
            return
        }
    }
    else
    {
        return
    }

    $skipUnlicensed = "0"
    if($ExportTxtSkipUnlicensed)
    {
        $skipUnlicensed = "1"
    }

    $exportCommand = "ExportObjects"
    if($ExportToNewSyntax)
    {
        $exportCommand = "ExportToNewSyntax"
    }

    $command = "Command=$exportCommand`,ExportTxtSkipUnlicensed=$skipUnlicensed`,File=`"$Path`""
    if($Filter)
    {
        $command = "$command`,Filter=`"$Filter`""
    }

    $logFile = (Join-Path $logPath naverrorlog.txt)

    try
    {
        RunNavIdeCommand -Command $command `
                         -DatabaseServer $DatabaseServer `
                         -DatabaseName $DatabaseName `
                         -NTAuthentication:($Username -eq $null) `
                         -Username $Username `
                         -Password $Password `
                         -NavServerInfo "" `
                         -LogFile $logFile `
                         -ErrText "Error while exporting $Filter" `
                         -Verbose:$VerbosePreference `
                         -SuppressElevationCheck $SuppressElevationCheck
        Get-Item $Path
    }
    catch
    {
        Write-Error $_
    }
}
#NV8 - S Custom function used in early stage of development to utilize ps stroed in the cloud
# function Cust-Export-NAVApplicationObject
# {
#     [CmdletBinding(DefaultParameterSetName="All",SupportsShouldProcess = $true)]
#     Param(
#         # Specifies the name of the database from which you want to export.
#         [Parameter(Mandatory=$true, Position=0)]
#         [string] $DatabaseName,

#         # Specifies the file to export to.
#         [Parameter(Mandatory=$true, Position=1)]
#         [string] $Path,

#         # Specifies the name of the SQL server instance to which the database you want to import into is attached. The default value is the default instance on the local host (.).
#         [ValidateNotNullOrEmpty()]
#         [string] $DatabaseServer = '.',

#         # Specifies the log folder.
#         [ValidateNotNullOrEmpty()]
#         [string] $LogPath = "$Env:TEMP\NavIde\$([GUID]::NewGuid().GUID)",

#         # Specifies the filter that selects the objects to export.
#         [string] $Filter,

#         # Allows the command to create a file that overwrites an existing file.
#         [Switch] $Force,

#         # Allows the command to skip application objects that are excluded from license, when exporting as txt.
#         [Switch] $ExportTxtSkipUnlicensed,

#         # Export the application object to the syntax supported by the Txt2Al converter.
#         [Switch] $ExportToNewSyntax,

#         # The user name to use to authenticate to the database. The user name must exist in the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
#         [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
#         [string] $Username,

#         # The password to use with the username parameter to authenticate to the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
#         [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
#         [string] $Password,

#         # Parameter to toggle on/off the elevation check when upgrading database. Default value is No (check on).
#         [ValidateSet('Yes','No','1','0')] 
#         [string] $SuppressElevationCheck = '0',
#         [string] $NewNavIde
#         )  
        
#     # Set-Variable -Name "NavIde" -Value $NewNavIde -Scope Local -Force
#     Write-Verbose "TestNavIde, Cust-Export NavIde: $($NavIde)"
#     if ($PSCmdlet.ShouldProcess(
#         "Export application objects from $DatabaseName database to $Path.",
#         "Export application objects from $DatabaseName database to $Path.",
#         'Confirm'))
#     {
#         if (!$Force -and (Test-Path $Path) -and !$PSCmdlet.ShouldContinue(
#             "$Path already exists. If you continue, $Path will be overwritten.",
#             'Confirm'))
#         {
#             Write-Error "$Path already exists."
#             return
#         }
#     }
#     else
#     {
#         return
#     }

#     $skipUnlicensed = "0"
#     if($ExportTxtSkipUnlicensed)
#     {
#         $skipUnlicensed = "1"
#     }

#     $exportCommand = "ExportObjects"
#     if($ExportToNewSyntax)
#     {
#         $exportCommand = "ExportToNewSyntax"
#     }

#     $command = "Command=$exportCommand`,ExportTxtSkipUnlicensed=$skipUnlicensed`,File=`"$Path`""
#     if($Filter)
#     {
#         $command = "$command`,Filter=`"$Filter`""
#     }

#     $logFile = (Join-Path $logPath naverrorlog.txt)

#     try
#     {
#         RunNavIdeCommand -Command $command `
#                          -DatabaseServer $DatabaseServer `
#                          -DatabaseName $DatabaseName `
#                          -NTAuthentication:($Username -eq $null) `
#                          -Username $Username `
#                          -Password $Password `
#                          -NavServerInfo "" `
#                          -LogFile $logFile `
#                          -ErrText "Error while exporting $Filter" `
#                          -Verbose:$VerbosePreference `
#                          -SuppressElevationCheck $SuppressElevationCheck
#         Get-Item $Path
#     }
#     catch
#     {
#         Write-Error $_
#     }
# }
#NV8 - E
<#
    .SYNOPSIS
    Deletes Business Central application objects from a database.

    .DESCRIPTION
    The Delete-NAVApplicationObject function deletes objects from the specified database. A filter can be specified to select the application objects to be deleted.

    .INPUTS
    None
    You cannot pipe input to this function.

    .OUTPUTS
    None

    .EXAMPLE
    Delete-NAVApplicationObject -DatabaseName MyApp -Filter 'Type=Codeunit;Id=1..10'
    Deletes codeunits 1..10 from the MyApp database
#>
function Delete-NAVApplicationObject
{
    [CmdletBinding(DefaultParameterSetName="All", SupportsShouldProcess=$true, ConfirmImpact='High')]
    Param(
        # Specifies the name of the database from which you want to delete objects.
        [Parameter(Mandatory=$true, Position=0)]
        [string] $DatabaseName,

        # Specifies the name of the SQL server instance to which the database you want to delete objects from is attached. The default value is the default instance on the local host (.).
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseServer = '.',

        # Specifies the log folder.
        [ValidateNotNullOrEmpty()]
        [string] $LogPath = "$Env:TEMP\NavIde\$([GUID]::NewGuid().GUID)",

        # Specifies the filter that selects the objects to delete.
        [string] $Filter,

        # Specifies the schema synchronization behaviour. The default value is 'Yes'.
        [ValidateSet('Yes','No','Force')]
        [string] $SynchronizeSchemaChanges = 'Yes',

        # The user name to use to authenticate to the database. The user name must exist in the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Username,

        # The password to use with the username parameter to authenticate to the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Password,

        # Specifies the name of the server that hosts the Business Central Server instance, such as MyServer.
        [ValidateNotNullOrEmpty()]
        [string] $NavServerName,

        # Specifies the Business Central Server instance that is being used.The default value is DynamicsNAV90.
        [ValidateNotNullOrEmpty()]
        [string] $NavServerInstance = "DynamicsNAV90",

        # Specifies the port on the Business Central Server instance that the Business Central Windows PowerShell cmdlets access. The default value is 7045.
        [ValidateNotNullOrEmpty()]
        [int16]  $NavServerManagementPort = 7045,

        # Parameter to toggle on/off the elevation check when upgrading database. Default value is No (check on).
        [ValidateSet('Yes','No','1','0')] 
        [string] $SuppressElevationCheck = '0')


    if ($PSCmdlet.ShouldProcess(
        "Delete application objects from $DatabaseName database.",
        "Delete application objects from $DatabaseName database.",
        'Confirm'))
    {
        $command = "Command=DeleteObjects`,SynchronizeSchemaChanges=$SynchronizeSchemaChanges"
        if($Filter)
        {
            $command = "$command`,Filter=`"$Filter`""
        }

        $logFile = (Join-Path $logPath naverrorlog.txt)
        $navServerInfo = GetNavServerInfo $NavServerName $NavServerInstance $NavServerManagementPort

        try
        {
            RunNavIdeCommand -Command $command `
                             -DatabaseServer $DatabaseServer `
                             -DatabaseName $DatabaseName `
                             -NTAuthentication:($Username -eq $null) `
                             -Username $Username `
                             -Password $Password `
                             -NavServerInfo $navServerInfo `
                             -LogFile $logFile `
                             -ErrText "Error while deleting $Filter" `
                             -Verbose:$VerbosePreference `
                             -SuppressElevationCheck $SuppressElevationCheck
        }
        catch
        {
            Write-Error $_
        }
    }
}

<#
    .SYNOPSIS
    Compiles Business Central application objects in a database.

    .DESCRIPTION
    The Compile-NAVApplicationObject function compiles application objects in the specified database. A filter can be specified to select the application objects to be compiled. Unless the Recompile switch is used only uncompiled objects are compiled.

    .INPUTS
    None
    You cannot pipe input to this function.

    .OUTPUTS
    None

    .EXAMPLE
    Compile-NAVApplicationObject MyApp
    Compiles all uncompiled application objects in the MyApp database.

    .EXAMPLE
    Compile-NAVApplicationObject MyApp -Filter 'Type=Codeunit' -Recompile
    Compiles all codeunits in the MyApp database.

    .EXAMPLE
    'Page','Codeunit','Table','XMLport','Report' | % { Compile-NAVApplicationObject -Database MyApp -Filter "Type=$_" -AsJob } | Receive-Job -Wait
    Compiles all uncompiled Pages, Codeunits, Tables, XMLports, and Reports in the MyApp database in parallel and wait until it is done. Note that some objects may remain uncompiled due to race conditions. Those remaining objects can be compiled in a seperate command.

#>
function Compile-NAVApplicationObject
{
    [CmdletBinding(DefaultParameterSetName="All")]
    Param(
        # Specifies the name of the database.
        [Parameter(Mandatory=$true, Position=0)]
        [string] $DatabaseName,

        # Specifies the name of the SQL server instance to which the database is attached. The default value is the default instance on the local host (.).
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseServer = '.',

        # Specifies the log folder.
        [ValidateNotNullOrEmpty()]
        [string] $LogPath = "$Env:TEMP\NavIde\$([GUID]::NewGuid().GUID)",

        # Specifies the filter that selects the objects to compile.
        [string] $Filter,

        # Compiles objects that are already compiled.
        [Switch] $Recompile,

        # Compiles in the background returning an object that represents the background job.
        [Switch] $AsJob,

        # Specifies the schema synchronization behaviour. The default value is 'Yes'.
        [ValidateSet('Yes','No','Force')]
        [string] $SynchronizeSchemaChanges = 'Yes',

        # The user name to use to authenticate to the database. The user name must exist in the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Username,

        # The password to use with the username parameter to authenticate to the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Password,

        # Specifies the name of the server that hosts the Business Central Server instance, such as MyServer.
        [ValidateNotNullOrEmpty()]
        [string] $NavServerName,

        # Specifies the Business Central Server instance that is being used.The default value is DynamicsNAV90.
        [ValidateNotNullOrEmpty()]
        [string] $NavServerInstance = "DynamicsNAV90",

        # Specifies the port on the Business Central Server instance that the Business Central Windows PowerShell cmdlets access. The default value is 7045.
        [ValidateNotNullOrEmpty()]
        [int16]  $NavServerManagementPort = 7045,

		#  Specifies that symbols should be generated for application objects as part of compilation.
		[Switch] $GenerateSymbolReference,

        # Parameter to toggle on/off the elevation check when upgrading database. Default value is No (check on).
        [ValidateSet('Yes','No','1','0')] 
        [string] $SuppressElevationCheck = '0')


    if (-not $Recompile)
    {
        $Filter += ';Compiled=0'
        $Filter = $Filter.TrimStart(';')
    }

    if ($AsJob)
    {
        $LogPath = "$LogPath\$([GUID]::NewGuid().GUID)"
        Remove-Item $LogPath -ErrorAction Ignore -Recurse -Confirm:$False -Force
        $scriptBlock =
        {
            Param($ScriptPath,$NavIde,$DatabaseName,$DatabaseServer,$LogPath,$Filter,$Recompile,$SynchronizeSchemaChanges,$Username,$Password,$NavServerName,$NavServerInstance,$NavServerManagementPort,$GenerateSymbolReference,$VerbosePreference)

            Import-Module "$ScriptPath\Microsoft.Dynamics.Nav.Ide.psm1" -ArgumentList $NavIde -Force -DisableNameChecking

            $args = @{
                DatabaseName = $DatabaseName
                DatabaseServer = $DatabaseServer
                LogPath = $LogPath
                Filter = $Filter
                Recompile = $Recompile
                SynchronizeSchemaChanges = $SynchronizeSchemaChanges
                GenerateSymbolReference = $GenerateSymbolReference
            }

            if($Username)
            {
                $args.Add("Username",$Username)
                $args.Add("Password",$Password)
            }

            if($NavServerName)
            {
                $args.Add("NavServerName",$NavServerName)
                $args.Add("NavServerInstance",$NavServerInstance)
                $args.Add("NavServerManagementPort",$NavServerManagementPort)
            }

            Compile-NAVApplicationObject @args -Verbose:$VerbosePreference
        }

        $job = Start-Job $scriptBlock -ArgumentList $PSScriptRoot,$NavIde,$DatabaseName,$DatabaseServer,$LogPath,$Filter,$Recompile,$SynchronizeSchemaChanges,$Username,$Password,$NavServerName,$NavServerInstance,$NavServerManagementPort,$GenerateSymbolReference,$VerbosePreference
        return $job
    }
    else
    {
        try
        {
            $logFile = (Join-Path $LogPath naverrorlog.txt)
            $navServerInfo = GetNavServerInfo $NavServerName $NavServerInstance $NavServerManagementPort
            $command = "Command=CompileObjects`,SynchronizeSchemaChanges=$SynchronizeSchemaChanges"
			
			if ($GenerateSymbolReference)
			{
				$command = "$command,GenerateSymbolReference=1"
			}

            if($Filter)
            {
                $command = "$command,Filter=`"$Filter`""
            }
			
			
            RunNavIdeCommand -Command $command `
                             -DatabaseServer $DatabaseServer `
                             -DatabaseName $DatabaseName `
                             -NTAuthentication:($Username -eq $null) `
                             -Username $Username `
                             -Password $Password `
                             -NavServerInfo $navServerInfo `
                             -LogFile $logFile `
                             -ErrText "Error while compiling $Filter" `
                             -Verbose:$VerbosePreference `
                             -SuppressElevationCheck $SuppressElevationCheck
        }
        catch
        {
            Write-Error $_
        }
    }
}

<#
    .SYNOPSIS
    Creates a new Business Central application database.

    .DESCRIPTION
    The Create-NAVDatabase creates a new Business Central database that includes the Business Central system tables.

    .INPUTS
    None
    You cannot pipe input into this function.

    .OUTPUTS
    None

    .EXAMPLE
    Create-NAVDatabase MyNewApp
    Creates a new Business Central database named MyNewApp.

    .EXAMPLE
    Create-NAVDatabase MyNewApp -ServerName "TestComputer01\BCDEMO" -Collation "da-dk"
    Creates a new Business Central database named MyNewApp on TestComputer01\BCDEMO Sql server with Danish collation.
#>
function Create-NAVDatabase
{
    [CmdletBinding(DefaultParameterSetName="All")]
    Param(
         # Specifies the name of the database that will be created.
        [Parameter(Mandatory=$true, Position=0)]
        [string] $DatabaseName,

        # Specifies the name of the SQL server instance on which you want to create the database. The default value is the default instance on the local host (.).
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseServer = '.',

        # Specifies the collation of the database.
        [ValidateNotNullOrEmpty()]
        [string] $Collation,

        # Specifies the log folder.
        [ValidateNotNullOrEmpty()]
        [string] $LogPath = "$Env:TEMP\NavIde\$([GUID]::NewGuid().GUID)",


        # The user name to use to authenticate to the database. The user name must exist in the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Username,

        # The password to use with the username parameter to authenticate to the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Password,

        # Parameter to toggle on/off the elevation check when upgrading database. Default value is No (check on).
        [ValidateSet('Yes','No','1','0')] 
        [string] $SuppressElevationCheck = '0')


    $logFile = (Join-Path $LogPath naverrorlog.txt)

    $command = "Command=CreateDatabase`,Collation=$Collation"

    try
    {
        RunNavIdeCommand -Command $command `
                         -DatabaseServer $DatabaseServer `
                         -DatabaseName $DatabaseName `
                         -NTAuthentication:($Username -eq $null) `
                         -Username $Username `
                         -Password $Password `
                         -NavServerInfo $navServerInfo `
                         -LogFile $logFile `
                         -ErrText "Error while creating $DatabaseName" `
                         -Verbose:$VerbosePreference `
                         -SuppressElevationCheck $SuppressElevationCheck
    }
    catch
    {
        Write-Error $_
    }
}

<#
    .SYNOPSIS
    Performs a technical upgrade of a database from a previous version of Microsoft Dynamics NAV or Microsoft Dynamics 365 Business Central.

    .DESCRIPTION
    Performs a technical upgrade of a database from a previous version of Microsoft Dynamics NAV or Microsoft Dynamics 365 Business Central.

    .INPUTS
    None
    You cannot pipe input into this function.

    .OUTPUTS
    None

    .EXAMPLE
    Invoke-NAVDatabaseConversion MyApp
    Perform the technical upgrade on a database named MyApp.

    .EXAMPLE
    Invoke-NAVDatabaseConversion MyApp -ServerName "TestComputer01\BCDEMO"
    Perform the technical upgrade on a database named MyApp on TestComputer01\BCDEMO Sql server .
#>
function Invoke-NAVDatabaseConversion
{
    [CmdletBinding(DefaultParameterSetName="All")]
    Param(
         # Specifies the name of the database that will be created.
        [Parameter(Mandatory=$true, Position=0)]
        [string] $DatabaseName,

        # Specifies the name of the SQL server instance on which you want to create the database. The default value is the default instance on the local host (.).
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseServer = '.',

        # Specifies the log folder.
        [ValidateNotNullOrEmpty()]
        [string] $LogPath = "$Env:TEMP\NavIde\$([GUID]::NewGuid().GUID)",

        # The user name to use to authenticate to the database. The user name must exist in the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Username,

        # The password to use with the username parameter to authenticate to the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Password,
        
        # Parameter to toggle on/off the elevation check when upgrading database. Default value is No (check on).
        [ValidateSet('Yes','No','1','0')] 
        [string] $SuppressElevationCheck = '0')

    $logFile = (Join-Path $LogPath naverrorlog.txt)

    $command = "Command=UpgradeDatabase"

    try
    {
        RunNavIdeCommand -Command $command `
                         -DatabaseServer $DatabaseServer `
                         -DatabaseName $DatabaseName `
                         -NTAuthentication:($Username -eq $null) `
                         -Username $Username `
                         -Password $Password `
                         -NavServerInfo "" `
                         -LogFile $logFile `
                         -ErrText "Error while converting $DatabaseName" `
                         -Verbose:$VerbosePreference `
                         -SuppressElevationCheck $SuppressElevationCheck
    }
    catch
    {
        Write-Error $_
    }
}

function TestNavIde
{  
    if (-not $NavIde -or (($NavIde) -and -not (Test-Path $NavIde)))
    {
        throw '$NavIde was not correctly set. Please assign the path to finsql.exe to $NavIde ($NavIde = path).'
    }
}

Export-ModuleMember -Function *-* -Variable Nav*
# SIG # Begin signature block
# MIInzwYJKoZIhvcNAQcCoIInwDCCJ7wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAnVwMQUtWc8wSl
# z2HTanY5V7She/a/yFYsSi8MqBYm/aCCDYEwggX/MIID56ADAgECAhMzAAACUosz
# qviV8znbAAAAAAJSMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjEwOTAyMTgzMjU5WhcNMjIwOTAxMTgzMjU5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDQ5M+Ps/X7BNuv5B/0I6uoDwj0NJOo1KrVQqO7ggRXccklyTrWL4xMShjIou2I
# sbYnF67wXzVAq5Om4oe+LfzSDOzjcb6ms00gBo0OQaqwQ1BijyJ7NvDf80I1fW9O
# L76Kt0Wpc2zrGhzcHdb7upPrvxvSNNUvxK3sgw7YTt31410vpEp8yfBEl/hd8ZzA
# v47DCgJ5j1zm295s1RVZHNp6MoiQFVOECm4AwK2l28i+YER1JO4IplTH44uvzX9o
# RnJHaMvWzZEpozPy4jNO2DDqbcNs4zh7AWMhE1PWFVA+CHI/En5nASvCvLmuR/t8
# q4bc8XR8QIZJQSp+2U6m2ldNAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUNZJaEUGL2Guwt7ZOAu4efEYXedEw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDY3NTk3MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAFkk3
# uSxkTEBh1NtAl7BivIEsAWdgX1qZ+EdZMYbQKasY6IhSLXRMxF1B3OKdR9K/kccp
# kvNcGl8D7YyYS4mhCUMBR+VLrg3f8PUj38A9V5aiY2/Jok7WZFOAmjPRNNGnyeg7
# l0lTiThFqE+2aOs6+heegqAdelGgNJKRHLWRuhGKuLIw5lkgx9Ky+QvZrn/Ddi8u
# TIgWKp+MGG8xY6PBvvjgt9jQShlnPrZ3UY8Bvwy6rynhXBaV0V0TTL0gEx7eh/K1
# o8Miaru6s/7FyqOLeUS4vTHh9TgBL5DtxCYurXbSBVtL1Fj44+Od/6cmC9mmvrti
# yG709Y3Rd3YdJj2f3GJq7Y7KdWq0QYhatKhBeg4fxjhg0yut2g6aM1mxjNPrE48z
# 6HWCNGu9gMK5ZudldRw4a45Z06Aoktof0CqOyTErvq0YjoE4Xpa0+87T/PVUXNqf
# 7Y+qSU7+9LtLQuMYR4w3cSPjuNusvLf9gBnch5RqM7kaDtYWDgLyB42EfsxeMqwK
# WwA+TVi0HrWRqfSx2olbE56hJcEkMjOSKz3sRuupFCX3UroyYf52L+2iVTrda8XW
# esPG62Mnn3T8AuLfzeJFuAbfOSERx7IFZO92UPoXE1uEjL5skl1yTZB3MubgOA4F
# 8KoRNhviFAEST+nG8c8uIsbZeb08SeYQMqjVEmkwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIZpDCCGaACAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAlKLM6r4lfM52wAAAAACUjAN
# BglghkgBZQMEAgEFAKCB0DAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgscM4bQEX
# tkNKuYuLYK8W+RJv8UFlEcZN/dO8N9YDhc8wZAYKKwYBBAGCNwIBDDFWMFSgNoA0
# AGcAbABvAGIAYQBsAGkAegBlAC4AYwB1AGwAdAB1AHIAZQAuAG0AcgAtAEkATgAu
# AGoAc6EagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAE
# ggEAUX/Kaw7TA6eQoA4YNUv5e8JptwvsdOdPkLi2/e9cZARBdoSQ+/1LCKOEMJb9
# meLzy5TBxZoLFMTr38oD4G7dSysRZOFd3eYQ+KgPcTdygIGkeOpncGJg7WnWV+aC
# OsOkKlVG5BCRpEUKKENWmALUqTiD9DqY2AlqJ+kfvlj0m0koqAdiat/vLhFwsvi9
# uONtPk3gqdJNuQ+6IOyaqRfABraLD96U94ex52ciQWdDFzNu5TSTKfsCMHTOOw/n
# HiuqfzOkaqaIY9PDPTgPsOrxUqpJn1s3h/nhDWaxIhiAYWHFYTnTD0RJPhq9cEbI
# lQD9G4ADfhyVlM7UgWtzgZhqU6GCFwwwghcIBgorBgEEAYI3AwMBMYIW+DCCFvQG
# CSqGSIb3DQEHAqCCFuUwghbhAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFVBgsqhkiG
# 9w0BCRABBKCCAUQEggFAMIIBPAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQC
# AQUABCDUXNLkm/FTAfKDyM/qs3+E0pISOOeJ22CyA0BtWuX65gIGYoS30a8JGBMy
# MDIyMDUyNjA0NTc0NS41NTZaMASAAgH0oIHUpIHRMIHOMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYDVQQLEyBNaWNyb3NvZnQgT3BlcmF0
# aW9ucyBQdWVydG8gUmljbzEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046RDlERS1F
# MzlBLTQzRkUxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghFfMIIHEDCCBPigAwIBAgITMwAAAaxmvIciXd49ewABAAABrDANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMjAzMDIxODUx
# MjlaFw0yMzA1MTExODUxMjlaMIHOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSkwJwYDVQQLEyBNaWNyb3NvZnQgT3BlcmF0aW9ucyBQdWVydG8g
# UmljbzEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046RDlERS1FMzlBLTQzRkUxJTAj
# BgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQDHeAtQxRdi7sdxzCvABJTHUxeIhvUTsikFhXoU
# 13vhF9UDq0wRZ4TACjRyEFqMZCtVutv6EEEJrSB6PLKYTLdVqZCzbwpty2vLHVS9
# 7fwQMe1FpJn77oydyg2koLd3JXObjT1I+3t9lOJ/xKfaDnPj7/xB3O1xh9Xxkby0
# WM8KMT9cZCpXrrGyM0/2ip+lgtgYID84x14p/ShO5K4grqgPiTYbJJHnUxyUCKLW
# 5Ufq2XLHsU0pozvme0dJn3h4lPA57b2b2f/WnfV1IQ8FCRSmfGWb8Z6p2V8BWJAy
# jWoGPINOgRdbw7pW5QLOgOIbj9Xu6bShaaQdVWZC1AJiFtccSRrN5HonQE1iFcdt
# rBlcnpmk9vTX7Q6f40bA8P2ocL9TZL+lr8pKLytJAzyGPUwlvXEW71HhJZPvglTO
# 3CKq5fEGN5oBEPKIuOVcxAV7mNOGNSoo2xi2ERTVMqVzEQwKVfpHIxvLkk9d5kgn
# 9ojIVkUS8/f48iMHu5Zl8+M1MmHJK/tjZvBq0quX1QD7ISDvAG/2jqOv6Htxt2Pn
# IpfIskSSyTcWzGMYkCSmb28ZQiKfqRiJ2g9d+9zOyjzxf8l3k+IRtC6lyr3pZILZ
# ac3nz65lFbqY2E4Hhn7qVMBc8pkpOCUTTtbYUQdGwygyMjTFahLr1dVMXXK4nFdK
# I4HiRwIDAQABo4IBNjCCATIwHQYDVR0OBBYEFFgRn3cEyx9AZ0o8fElamFrAQI5N
# MB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBS
# oFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29m
# dCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRg
# MF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# Y2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0
# MAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZIhvcNAQEL
# BQADggIBAHnQtQJYVVxwpXZPLaCMwFvUMiE3EXsoVKbNbg+u8wgt9PH0c2BREv9r
# zF+6NDmyYMwsU9Z4tL5HLPFhtjFCLJPdUQjyHg800CLSKY/WU8/YdLbn3Chpt2oZ
# J0bNYaFddo0RZHGqlyaNX7MrqCoA/hU09pTr6xLDYyYecBLIvjwf5lZofyWtFbvI
# 4VCXNYawVEOWIrEODdNLJ2cITqAnj123Q+hxrNXJrF2W65E/LzT2FfC5yOJcbif2
# GmEttKkK+mPQyBxQzWMWW05bEHl7Pyo54UTXRYghqAHCx1sHlnkbM4dolITH2Nf+
# /Xe7KJn48emciT2Tq+HxNFE9pf6wWgU66D6Qzr6WjrGOhP7XiyzH8p6+lDkHhOJU
# YsOfbIlRsgBqqUwU23cwBSwRR+NLm6+1RJXZo4h2teBJGcWL3IMysSqrm+Mqymn6
# P4/WlG8C6y9lTB1nKWtfCYb+syI3dNSBpFHY91CfiSkDQM+Xsj8kEmT7fcLPG8p6
# HRpTOZ2JBwcu6z74+Ocvmc+46y4I4L2SIsRrM8KisiieOwDx8ax/BowkLrG71vTR
# eCwGCqGWRo+z8JkAPl5sA+bX1ENCrszERZjKTlM7YkwICY0H/UzLnN6WJqRVhK/J
# LGHcK463VmACwlwPyEFxHQIrEMI+WM07IeEMU1Kvr0UsbPd8gd5yMIIHcTCCBVmg
# AwIBAgITMwAAABXF52ueAptJmQAAAAAAFTANBgkqhkiG9w0BAQsFADCBiDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9z
# b2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMwMTgy
# MjI1WhcNMzAwOTMwMTgzMjI1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOThpkzntHIhC3miy9ck
# eb0O1YLT/e6cBwfSqWxOdcjKNVf2AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+Slr+
# uDZnhUYjDLWNE893MsAQGOhgfWpSg0S3po5GawcU88V29YZQ3MFEyHFcUTE3oAo4
# bo3t1w/YJlN8OWECesSq/XJprx2rrPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+tuhi
# JdxqD89d9P6OU8/W7IVWTe/dvI2k45GPsjksUZzpcGkNyjYtcI4xyDUoveO0hyTD
# 4MmPfrVUj9z6BVWYbWg7mka97aSueik3rMvrg0XnRm7KMtXAhjBcTyziYrLNueKN
# iOSWrAFKu75xqRdbZ2De+JKRHh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZnkXf
# tnIv231fgLrbqn427DZM9ituqBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n6Jl8
# P0zbr17C89XYcz1DTsEzOUyOArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC4jMY
# ctenIPDC+hIK12NvDMk2ZItboKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiER9vcG9H9
# stQcxWv2XFJRXRLbJbqvUAV6bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/eKtFtvUe
# h17aj54WcmnGrnu3tz5q4i6tAgMBAAGjggHdMIIB2TASBgkrBgEEAYI3FQEEBQID
# AQABMCMGCSsGAQQBgjcVAgQWBBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNVHQ4E
# FgQUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3TIN9
# AQEwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsG
# AQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTAD
# AQH/MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0w
# S6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYI
# KwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWlj
# Um9vQ2VyQXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCdVX38
# Kq3hLB9nATEkW+Geckv8qW/qXBS2Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQdTlt
# uw8x5MKP+2zRoZQYIu7pZmc6U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gngugnue99q
# b74py27YP0h1AdkY3m2CDPVtI1TkeFN1JFe53Z/zjj3G82jfZfakVqr3lbYoVSfQ
# JL1AoL8ZthISEV09J+BAljis9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHCgRlCGVJ1
# ijbCHcNhcy4sa3tuPywJeBTpkbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZlvSP
# 9pEB9s7GdP32THJvEKt1MMU0sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/ZPkk
# vnNtyo4JvbMBV0lUZNlz138eW0QBjloZkWsNn6Qo3GcZKCS6OEuabvshVGtqRRFH
# qfG3rsjoiV5PndLQTHa1V1QJsWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+y/g7
# 5LcVv7TOPqUxUYS8vwLBgqJ7Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrpNPgkNWcr
# 4A245oyZ1uEi6vAnQj0llOZ0dFtq0Z4+7X6gMTN9vMvpe784cETRkPHIqzqKOghi
# f9lwY1NNje6CbaUFEMFxBmoQtB1VM1izoXBm8qGCAtIwggI7AgEBMIH8oYHUpIHR
# MIHOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYDVQQL
# EyBNaWNyb3NvZnQgT3BlcmF0aW9ucyBQdWVydG8gUmljbzEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046RDlERS1FMzlBLTQzRkUxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVALEa0hOwuLBJ/egDIYzZ
# F2dGNYqgoIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJ
# KoZIhvcNAQEFBQACBQDmORk8MCIYDzIwMjIwNTI2MDEwODEyWhgPMjAyMjA1Mjcw
# MTA4MTJaMHcwPQYKKwYBBAGEWQoEATEvMC0wCgIFAOY5GTwCAQAwCgIBAAICEGEC
# Af8wBwIBAAICEQgwCgIFAOY6arwCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYB
# BAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQUFAAOB
# gQASeowtjczYA6fimIb3C6Yo3yFINSxvDdIMx3Dli74hdiHVtgciIhnqZARjw5FI
# tbUXm1eJv3CG5xw1o7s4bHm3mGQ90NtqprNVv8CoK8hggc5EDnvKklesYk6r3/rR
# u5mGIh9YrRJhPdwZA3YIdAG0Hifcai+NYHhJ03YrnHDywzGCBA0wggQJAgEBMIGT
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABrGa8hyJd3j17AAEA
# AAGsMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQ
# AQQwLwYJKoZIhvcNAQkEMSIEIBrBJE8zA0I47O6gyL5xlejL4lzwssH8rk/An5tf
# yAegMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQg+bcBkoM4LwlxAHK1c+ep
# u/T6fm0CX/tPi4Nn2gQswvUwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0EgMjAxMAITMwAAAaxmvIciXd49ewABAAABrDAiBCDPOqUGo8as0sQpu0zhnYka
# XBR/Ck/tbI8xbFiiGdI/CjANBgkqhkiG9w0BAQsFAASCAgCmsu3PhUb0j4gLClX9
# hQM8rETtyQD0b3kOabJAqjH0dQRZ8bLKF7RIFmFVqsAfN66TR8caePKLc+HP7CdN
# NjNzcAffWT2entL9T+WOp3togQlavnN1V0E587dgJnbOQFxWbeCX7tQjdqk1ke+j
# mNXnMDgykm98SxPEkCFMmg0CNUw8umiKIaS9Zb/sBtRHBjXpGgStsm2thNmb57md
# j2Z/PKDiA9B9iSHnwsVsJmMoGC7eJK7icSXnmATOh4kF0p5f876ub0Bw+imz9Gsz
# enAIqcR2JZ2ha/UwFfh9PuhH143UIRRFcfwgCXT8JwDLXdoBX7M4byBUE7bmY2KF
# zK6BetaxZk5r1sOQ1uebErfbUdoz6MKejYcnhZH+/A+LlpweSw1v16GDb7nn41l6
# +yljgTpucZ/Q34UC1s12hqffyaovnIGO6JPGo6y7hWCuEsv+h1g46FD9IR3nAngh
# +x3akqstd7MJZcdMLSahybPLw2swtx35we2KmgBfkp/ijpMJDZJrDJCryE1MVuuZ
# z7rkTHIv5vp5UCgjM5rlhF8+ZCKHU9tMPMBkenvLpUAH5iDhzviuwuWw7ajE3bWn
# 8YFAl2iyF0OgZM0NHSb9iEMLXuamXbwGVS6a/PthKSoImwwZGXCA1qTOE45moWFi
# hYxVeG1uYLpJoaJydYTmgoELsQ==
# SIG # End signature block
