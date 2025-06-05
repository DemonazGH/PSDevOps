function Write-JSONFileForVariables{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][String] $SOXNumber
    )
    [string]$VariablesFilePath = $pipelineStagingVariablesFilePath
    Write-Host $VariablesFilePath
    try { 
        $fn = '{0}' -f $MyInvocation.MyCommand
        Write-InitialLogs -fn $fn
        # Delete variables file
        if (Test-Path -Path $VariablesFilePath -PathType Leaf) {
            Remove-Item -Path $VariablesFilePath -Force
        }
        if (Test-Path -Path $VariablesFilePath -PathType Leaf) {
            throw 'ERROR: Unable to delete existing Version Control Pipeline Values file: ' + $VariablesFilePath
        }
        $resultObj = [ordered]@{}
        $resultObj | ConvertTo-Json | Out-File $VariablesFilePath
        if (-Not(Test-Path -Path $VariablesFilePath -PathType Leaf)) {
            throw "ERROR: Unable to create restart global variables file: $VariablesFilePath"
        }
        Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "CheckLogFilePath" -NewValue $CheckLogFilePath
        $LogBuffer = New-Object System.Text.StringBuilder
        Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "LogBuffer" -NewValue $LogBuffer
        if ($SOXNumber -ne $DummySOXNumber)
        {
            Update-ValueByKeyJSONWithVariables -JsonFilePath $VariablesFilePath -KeyName "SOXNumber" -NewValue $SOXNumber
        }

        Write-HostAndLog ("Saving Version Control Pipeline Values to file: $VariablesFilePath")
    }
    catch {
        $errorMessage = $_
        Write-Host($_)
        Write-HostAndLog ("Error: $errorMessage")
        throw $errorMessage 
    }
    finally
    {
        Write-LogsToFile -Message $LogBuffer.ToString() -VariablesPath $VariablesFilePath
    }
}