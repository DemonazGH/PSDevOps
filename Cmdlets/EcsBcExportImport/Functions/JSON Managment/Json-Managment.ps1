function SafeSet-Content {
    param (
        [string]$Path,
        [string]$Content,
        [int]$Retries = 5,
        [int]$DelayMs = 200
    )

    for ($i = 0; $i -lt $Retries; $i++) {
        try {
            Set-Content -Path $Path -Value $Content -Encoding UTF8
            return
        } catch {
            if ($i -eq $Retries - 1) {
                throw "Failed to write to $Path after $Retries attempts. $_"
            }
            Start-Sleep -Milliseconds $DelayMs
        }
    }
}

function Update-ValueByKeyJSONWithVariables { 
    param (
        [string]$JsonFilePath,
        [string]$KeyName,
        [Object]$NewValue  # Supports both strings and arrays
    )

    # Load existing JSON or create a new object
    if (Test-Path $JsonFilePath) {
        $jsonData = Get-Content -Path $JsonFilePath -Raw | ConvertFrom-Json
    } else {
        $jsonData = @{}
    }

    # Conditional logging
    if ($KeyName -eq "NavFoldersArray") {
        Write-Host "Logging for NavFoldersArray:"
        Write-Host " - Count of items: $($NewValue.Count)"
        foreach ($item in $NewValue) {
            Write-Host "   • SOXNumber: $($item.SOXNumber) - ChangedObjectsSourceFolder: $($item.ChangedObjectsSourceFolder)"
        }
    }

    # Update the key
    if ($jsonData.PSObject.Properties.Name -contains $KeyName) {
        $jsonData.$KeyName = $NewValue
    } else {
        $jsonData | Add-Member -NotePropertyName $KeyName -NotePropertyValue $NewValue
    }

    # Convert to JSON string
    $jsonString = $jsonData | ConvertTo-Json -Depth 10

    # Safe write to file
    SafeSet-Content -Path $JsonFilePath -Content $jsonString
}
function Get-ValueByKeyJSONWithVariables {
    param (
        [string]$JsonFilePath,
        [string]$KeyName
    )

    # Check if JSON file exists
    if (!(Test-Path $JsonFilePath)) {
        Write-Error "JSON file not found: $JsonFilePath"
        #return $null
    }

    # Load JSON data
    $jsonData = Get-Content -Path $JsonFilePath | ConvertFrom-Json

    # Retrieve the requested variable
    if ($jsonData.PSObject.Properties.Name -contains $KeyName) {
        return $jsonData.$KeyName
    } else {
        if ($KeyName -ne 'CheckLogFilePath')
        {
            Write-Error "Variable '$KeyName' not found in JSON."
        }
        #return $null
    }
    # $stage1Value = Read-JSON -JsonFilePath "pipeline_variables.json" -KeyName "Stage1Var"
    # Write-HostAndLog "Stage1Var: $stage1Value"
    # $stage2Value = Read-JSON -JsonFilePath "pipeline_variables.json" -KeyName "Stage2Var"
    # Write-HostAndLog "Stage2Var: $stage2Value"
}

function Confirm-KeyExistsInJSONWithVariables {
    param (
        [string]$JsonFilePath,
        [string]$KeyName
    )

    # Check if JSON file exists
    if (!(Test-Path $JsonFilePath)) {
        Write-Error "JSON file not found: $JsonFilePath"
    }
    # Load JSON data
    $jsonData = Get-Content -Path $JsonFilePath | ConvertFrom-Json

    # Retrieve the requested variable
    if ($jsonData.PSObject.Properties.Name -contains $KeyName) {
        return $true
    } else {
        return $false
    }

}

# Example Usage
# Overwriting a string value
# Update-ValueByKeyJSONWithVariables -JsonFilePath "pipeline_variables.json" -KeyName "Stage1Var" -NewValue "UpdatedValue1"

# # Overwriting an array value
# Update-ValueByKeyJSONWithVariables -JsonFilePath "pipeline_variables.json" -KeyName "Stage2Var" -NewValue @("ItemA", "ItemB", "ItemC")