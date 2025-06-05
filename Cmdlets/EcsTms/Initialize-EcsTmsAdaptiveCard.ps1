function Initialize-EcsTmsAdaptiveCard { 

    # Initialize the Adaptive Card
    $adaptiveCard = @{
        type    = "AdaptiveCard"
        version = "1.4"
        body    = @()
        msteams = @{
            width = "Full"
        }
    }
    return $adaptiveCard
    <#
    .SYNOPSIS
    Initializes a new Adaptive Card.

    .DESCRIPTION
    This function creates an Adaptive Card object with default settings, including type, version, body, 
    and Microsoft Teams-specific properties. The resulting card is suitable for use in Microsoft Teams or
    other environments supporting Adaptive Cards.
    #>

}