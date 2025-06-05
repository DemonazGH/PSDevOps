function Write-CheckLogFile {
    [CmdletBinding()]
    [string]$filePath = $CheckLogFilePath
    if (-not (Test-Path -Path $global:globalDevServerRootFolder)) {
        try {
            New-Item -Path $global:globalDevServerRootFolder -ItemType Directory -Force | Out-Null
            Write-Host "Created folder: $($global:globalDevServerRootFolder)"
        } catch {
            Write-Error "Failed to create folder $($global:globalDevServerRootFolder): $_"
        }
    } else {
        Write-Host "Folder already exists: $($global:globalDevServerRootFolder)"
    }
    # Delete variables file
    if (Test-Path -Path $filePath -PathType Leaf) {
        Remove-Item -Path $filePath -Force
    }
    if (Test-Path -Path $filePath -PathType Leaf) {
        throw 'ERROR: Unable to delete existing Version Control Pipeline Logs file: ' + $filePath
    }
    $resultObj = [ordered]@{} 
    
    $resultObj | Out-File $filePath
    if (-Not(Test-Path -Path $filePath -PathType Leaf)) {
        throw "ERROR: Unable to create global Logs file: $filePath"
    }
}