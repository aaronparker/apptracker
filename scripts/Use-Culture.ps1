function Use-Culture {
    <#
        ## Use-Culture
        ##
        ## From Windows PowerShell Cookbook (O'Reilly)
        ## by Lee Holmes (http://www.leeholmes.com/guide)

        .SYNOPSIS
        Invoke a scriptblock under the given culture

        .EXAMPLE
        PS > Use-Culture fr-FR { Get-Date -Date "25/12/2007" }
        mardi 25 decembre 2007 00:00:00
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        ## The culture in which to evaluate the given script block
        [Parameter(Mandatory = $true)]
        [System.Globalization.CultureInfo] $Culture,

        ## The code to invoke in the context of the given culture
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )

    Set-StrictMode -Version 3

    ## A helper function to set the current culture
    function Set-Culture {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param ([System.Globalization.CultureInfo] $Culture)
        if ($PSCmdlet.ShouldProcess($Culture, "Setting culture")) {
            [System.Threading.Thread]::CurrentThread.CurrentUICulture = $Culture
            [System.Threading.Thread]::CurrentThread.CurrentCulture = $Culture
        }
    }

    ## Remember the original culture information
    $OldCulture = [System.Threading.Thread]::CurrentThread.CurrentUICulture

    ## Restore the original culture information if
    ## the user's script encounters errors.
    trap { Set-Culture -Culture $OldCulture }

    ## Set the current culture to the user's provided
    ## culture.
    if ($PSCmdlet.ShouldProcess($Culture, "Setting culture; Run script block")) {
        Set-Culture -Culture $Culture

        ## Invoke the user's scriptblock
        & $ScriptBlock

        ## Restore the original culture information.
        Set-Culture -Culture $OldCulture
    }
}
