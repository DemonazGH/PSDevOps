# enum ObjType {

#     Table = 1
#     Report = 3
#     Codeunit = 5
#     XMLport = 6
#     MenuSuite = 7
#     Page = 8
#     Query = 9

# }
# enum SoxStatuses
# {
#     Development = 300
#     Redevelopment = 301
#     SIT = 400
#     UAT = 500
#     Approval = 600
#     MTPCandidate = 800
#     Finished = 900
#     Done = 990
# }

function Type2Text([Parameter(Mandatory = $true)][int]$Type)
{
    # Option: TableData,Table,,Report,,Codeunit,XMLport,MenuSuite,Page,Query,System,FieldNumber
    [string]$output = ""
    switch ($Type)
    {
        #0 { $output = "tabledata" } # 0 is filtered out in the SQL Statement, so no need for this value
        1 { $output = "table" }
        3 { $output = "report" }
        5 { $output = "codeunit" }
        6 { $output = "xmlport" }
        7 { $output = "menusuite" }
        8 { $output = "page" }
        9 { $output = "query" }
    }

    return $output
}
function Text2Type {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $Text = $Text.ToLowerInvariant()

    switch ($Text) {
        "table"      { return 1 }
        "report"     { return 3 }
        "codeunit"   { return 5 }
        "xmlport"    { return 6 }
        "menusuite"  { return 7 }
        "page"       { return 8 }
        "query"      { return 9 }
        default      { return -10 }  # or throw "Unknown object type: $Text"
    }
}

function Convert-ToCustomDateTimeFormat {
    param (
        [datetime]$InputDate = (Get-Date)
    )
    # Format the date in "yyyy-MM-dd HH:mm:ss.fff"
    $formattedDate = $InputDate.ToString("yyyy-MM-dd 00:00:00.000")
    return $formattedDate
}

function Get-Filter-By-SOXNumber {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VersionTag
    )
    $FilterString = "Version List=*, $VersionTag|*,$VersionTag|$VersionTag"
    return $FilterString 
}

function Get-Filter-By-SOXNumber-Array {
    param (
        [Parameter(Mandatory=$true)]
        [array]$SOXArray
    )

    $res = foreach ($tag in $SOXArray) {
        "$tag"
        "$tag,*"
        "*,${tag},*"
        "*,${tag}"
         "*, ${tag} *"
    }

    $FilterString = "Version List=" + ($res -join '|')
    return $FilterString
}

function Get-EnvironmentsConfigJSONFilePath {
    return $LiveBCServerConfig
}

function Get-NavInstanceName {
    param (
        [string]$FullName
    )
    if ($FullName -match '\$(.+)$') {
        return $Matches[1]
    } 
    else 
    {
        return $null
    }
}

function Write-LogsToFile {
    Param([Parameter(Position=0)][String]$message,
    [Parameter(Position=1,Mandatory=$false)][ConsoleColor]$color = (get-host).ui.rawui.ForegroundColor,
    [Parameter(Position=2)][String]$variablesPath
         )
        try {  
            $path = Get-ValueByKeyJSONWithVariables -JsonFilePath $variablesPath -KeyName "CheckLogFilePath"
        }
        catch {
            $path = $CheckLogFilePath
        }

    if  (-not [string]::IsNullOrWhiteSpace($path)) {   
            $ShouldWait = $true
            while ($ShouldWait)
            {
                try {
                    Add-Content -Path $path -Value $message -Encoding UTF8 
                    $ShouldWait = $false
                }
                catch {
                    $ShouldWait = $true
                    Write-Host('Trying to write to Log File. Retrying. See error text below:')
                    Write-Host($_)
                    Start-Sleep -Milliseconds 500
                }
            }
    }
}

function Write-HostAndLog {
    Param([Parameter(Position=0)][String]$message
         ,[Parameter(Position=1,Mandatory=$false)][string]$color 
         )
    if ($color)
    {
        Write-DevOpsLog $message -Color $color
    }
    else {
        Write-Host $message
    }

    try {  
        $null = $LogBuffer.AppendLine($message)
    }
    catch {
        Write-Host("Can't append to LogBuffer. See error: $_")
    }
}

function Write-DevOpsLog {
    param (
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $true)]
        [string]$Color
    )

    $prefix = switch ($Color.ToLower()) {
        "red"     { "##[error]" }
        "green"   { "##[section]" }
        "purple"  { "##[debug]" }
        "blue"    { "##[command]" }
        "yellow"  { "##[warning]" }
        default   {""}
    }

    Write-Host "$prefix$Message"
}