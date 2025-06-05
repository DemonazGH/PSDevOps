function Read-JsonFromFile {
    param (
        [string]$RelativeFilePath
    )

    # Resolve the relative path to an absolute path
    $absolutePath = Join-Path -Path (Get-Location) -ChildPath $RelativeFilePath
    # Check if the file exists
    if (Test-Path -Path $absolutePath) {
        try {
            # Read the content of the JSON file
            $jsonContent = Get-Content -Path $absolutePath -Raw

            # Parse the JSON content
            $parsedJson = $jsonContent | ConvertFrom-Json

            # Return the parsed JSON object
            return $parsedJson
        }
        catch {
            Write-Error "Failed to parse JSON file: $_" 
        }
    }
    else {
        Write-Error "File not found at path: $absolutePath" 
    }
}