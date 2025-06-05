function Initialize-EcsTmsContainerForAdaptiveCard {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The title of the container, typically used as a header or identifier.")]
        [string]$Title,

        [Parameter(Mandatory = $false, Position = 1, HelpMessage = "The color of the message text, indicating its importance or context.")]
        [ValidateSet("Default", "Good", "Attention", "Warning", "Accent")]
        [string]$TitleColor = "Default",

        [Parameter(Mandatory = $false, Position = 2, HelpMessage = "The font size of the title text.")]
        [ValidateSet("Small", "Default", "Medium", "Large", "ExtraLarge")]
        [string]$FontSize = "Medium",

        [Parameter(Mandatory = $false, Position = 3, HelpMessage = "The weight of the title text, indicating emphasis.")]
        [ValidateSet("Lighter", "Default", "Bolder")]
        [string]$TitleWeight = "Bolder",

        [Parameter(Mandatory = $false, Position = 4, HelpMessage = "Whether to wrap the title text if it exceeds the container width.")]
        [bool]$WrapTitle = $true,

        [Parameter(Mandatory = $false, Position = 5, HelpMessage = "Whether to add a separator above the container.")]
        [bool]$Separator = $false,

        [Parameter(Mandatory = $false, Position = 6, HelpMessage = "The spacing applied around the container.")]
        [ValidateSet("None", "Small", "Default", "Medium", "Large", "ExtraLarge", "Padding")]
        [string]$Spacing = "Default"
    )

    # Create a container with the specified title and message
    $container = @{
        type = "Container"
        items = @(
            @{
                type      = "TextBlock"
                text      = $Title
                color     = $TitleColor
                size      = $FontSize
                weight    = $TitleWeight
                wrap      = $WrapTitle
                separator = $Separator
                spacing   = $Spacing
            }
        )
    }

    # Return the container to be added later in the code
    return $container

    <#
    .SYNOPSIS
    Initializes a container for an Adaptive Card.

    .DESCRIPTION
    This function creates a container element for an Adaptive Card with a specified title, color, font size, weight, and other properties.
    The container can be used to group multiple elements within an Adaptive Card. The container is returned as a hashtable, which can be used 
    in constructing adaptive card JSON payloads.
#>

}

