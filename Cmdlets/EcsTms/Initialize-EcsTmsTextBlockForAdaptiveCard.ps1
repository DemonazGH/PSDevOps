function Initialize-EcsTmsTextBlockForAdaptiveCard {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0, HelpMessage = "The message text to be displayed in the text block.")]
        [string]$Message = "",

        [Parameter(Mandatory = $false, Position = 1, HelpMessage = "The color of the message text, indicating its importance or context.")]
        [ValidateSet("Default", "Good", "Attention", "Warning", "Accent")]
        [string]$TextColor = "Default",
       
        [Parameter(Mandatory = $false, Position = 2, HelpMessage = "The weight of the message text, indicating emphasis.")]
        [ValidateSet("Lighter", "Default", "Bolder")]
        [string]$TextWeight = "Default",

        [Parameter(Mandatory = $false, Position = 3, HelpMessage = "Whether to wrap the text if it exceeds the block width.")]
        [bool]$WrapText = $true,
       
        [Parameter(Mandatory = $false, Position = 4, HelpMessage = "The spacing applied around the text block, affecting layout positioning.")]
        [ValidateSet("None", "Small", "Default", "Medium", "Large", "ExtraLarge", "Padding")]
        [string]$Spacing = "Default",

        [Parameter(Mandatory = $false, Position = 5, HelpMessage = "The font size of the message text.")]
        [ValidateSet("Small", "Default", "Medium", "Large", "ExtraLarge")]
        [string]$FontSize = "Default",

        [Parameter(Mandatory = $false, Position = 6, HelpMessage = "Whether to add a separator above the text block.")]
        [bool]$Separator = $false,

        [Parameter(Mandatory = $false, Position = 7, HelpMessage = "Horizontal alignment of the text within the text block.")]
        [ValidateSet("Left", "Center", "Right")]
        [string]$HorizontalAlignment = "Left"
    )

    # Create a simple text block with the message
    $textBlock = @{
        type                = "TextBlock"
        text                = $Message
        color               = $TextColor
        weight              = $TextWeight
        wrap                = $WrapText
        spacing             = $Spacing
        size                = $FontSize
        separator           = $Separator
        horizontalAlignment = $HorizontalAlignment
    }

    # Return the text block
    return $textBlock

    <#
    .SYNOPSIS
    Initializes a text block for an Adaptive Card with customizable properties.

    .DESCRIPTION
    This function creates a text block element for an Adaptive Card with various customization options such as color, weight, wrapping, spacing,
    font size, separator, and horizontal alignment. The text block is returned as a hashtable, which can be used in constructing adaptive card JSON payloads.
#>
}