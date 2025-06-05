function Rename-CompanyForIberia {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$ServerInstance,
        [Parameter(Mandatory = $true)] [string]$envShortName_arg
    )

    try {
        $companies = Get-NAVCompany -ServerInstance $ServerInstance
        $CurrentDate = (Get-Date).ToString("ddMMyy")
        $suffix = "_${envShortName_arg}_$CurrentDate"
        $maxCompanyNameLength = 30

        # Output company names
        foreach ($company in $companies) {
            [string]$companyName = $company.CompanyName
            Write-Host "Checking company: $companyName"
        
            # Skip if already renamed
            if ($companyName -like "*_${envShortName_arg}_$CurrentDate") {
                Write-Host "Company '$companyName' already renamed. Skipping..."
                continue
            }
            # Calculate allowed length for base name
            $allowedBaseLength = $maxCompanyNameLength - $suffix.Length
            # Truncate if needed
            if ($companyName.Length -gt $allowedBaseLength) {
                Write-Warning "Company name '$companyName' too long, truncating to fit the 30-char limit."
                $trimmedName = $companyName.Substring(0, $allowedBaseLength)
            }
            else {
                $trimmedName = $companyName
            }
            # Construct new company name with required format
            
            $NewCompanyName = $trimmedName + $suffix

            Write-Host "Renaming BC Company from '$companyName' to '$NewCompanyName'..."
            try {
                Rename-NAVCompany -ServerInstance $ServerInstance `
                                  -CompanyName    $companyName `
                                  -NewCompanyName        $NewCompanyName

                Write-Host "Company renamed successfully to: $NewCompanyName"
            }
            catch {
                Write-Error "Error encountered when renaming $companyName : $_"
                throw
            }
        }
    }
    catch {
        Write-Error "Failed to rename company: $_"
        throw
    }
    finally {
        Write-Host "Rename-BcCompanyForIberia function completed."
    }

}
<## >
Rename-CompanyForIberia
<##>