<#
.DESCRIPTION
    This script will test the basic container creation.

#>

Import-Module .\bin\Module\Docker\Docker.psm1 -Force
. .\test\pester\\Utils.ps1

function Test-StartContainer
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

        $container | Start-Container

        $container | Wait-Container
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

Describe "Start-Container - Test matrix of types and hosts." {
    It "Start_WindowsServerCore" -Skip:$(Test-Client -or Test-Nano) {
        { Test-StartContainer $global:WindowsServerCore $false } | Should Not Throw
    }

    It "Start_WindowsServerCore_Isolated" {
        { Test-StartContainer $global:WindowsServerCore $true } | Should Not Throw
    }

    It "Start_NanoServer" -Skip:$(Test-Client) {
        { Test-StartContainer $global:NanoServer $false } | Should Not Throw
    }

    It "Start_NanoServer_Isolated" {
        { Test-StartContainer $global:NanoServer $true } | Should Not Throw
    }
}