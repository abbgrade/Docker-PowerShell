<#
.DESCRIPTION
    This script will test the basic container creation.

#>

Import-Module .\bin\Module\Docker\Docker.psm1 -Force
. .\test\pester\\Utils.ps1

function Test-NewContainer
{
    param(
        [string]
        [ValidateNotNullOrEmpty()]
        $ImageName,

        [bool]
        $IsIsolated
    )

    $isolation = [Docker.PowerShell.Objects.IsolationType]::Default
    if ($IsIsolated)
    {
        $isolation = [Docker.PowerShell.Objects.IsolationType]::HyperV
    }

    try 
    {
        $container = New-Container -ImageName "$ImageName" -Isolation $isolation -Command @("cmd", "/c", "echo Worked")
        $container | Should Not Be $null
    }
    finally
    {
        # Cleanup
        if ($container)
        {
            $container | Remove-Container
        }
    }
}

Describe "New-Container - Test matrix of types and hosts." {
    It "Create_WindowsServerCore" -Skip:$(Test-Client -or Test-Nano) {
        { Test-NewContainer $global:WindowsServerCore $false } | Should Not Throw
    }

    It "Create_WindowsServerCore_Isolated" {
        { Test-NewContainer $global:WindowsServerCore $true } | Should Not Throw
    }

    It "Create_NanoServer" -Skip:$(Test-Client) {
        { Test-NewContainer $global:NanoServer $false } | Should Not Throw
    }

    It "Create_NanoServer_Isolated" {
        { Test-NewContainer $global:NanoServer $true } | Should Not Throw
    }
}