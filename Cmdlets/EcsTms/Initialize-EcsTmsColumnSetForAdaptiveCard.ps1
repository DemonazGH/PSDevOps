function Initialize-EcsTmsColumnSetForAdaptiveCard {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "A list of columns to add to the ColumnSet.")]
        [array]$Columns,

        [Parameter(Mandatory = $false, HelpMessage = "Whether to add a separator above the column set.")]
        [bool]$Separator = $false,

        [Parameter(Mandatory = $false, HelpMessage = "The spacing around the ColumnSet.")]
        [ValidateSet("None", "Small", "Default", "Medium", "Large", "ExtraLarge", "Padding")]
        [string]$Spacing = "Default"
    )

    # Create a ColumnSet with the specified columns
    $columnSet = @{
        type      = "ColumnSet"
        columns   = $Columns
    }

    # Optional properties
    if ($Separator) {
        $columnSet.separator = $Separator
    }

    if ($Spacing -ne "Default") {
        $columnSet.spacing = $Spacing
    }

    # Return the ColumnSet
    return $columnSet

        <#
    .SYNOPSIS
    Initializes a ColumnSet for use in an Adaptive Card.

    .DESCRIPTION
    This function creates a ColumnSet object for an Adaptive Card. A ColumnSet allows grouping multiple columns together, 
    each of which can hold a variety of content types. The function is used to create a structured layout for Adaptive Cards,
    making it easier to present tabular or side-by-side information.
#>

}
