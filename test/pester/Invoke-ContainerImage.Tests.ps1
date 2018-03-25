<#
.DESCRIPTION
    This script will test the basic Invoke-ContainerImage cmdlet operations.
#>

Import-Module .\bin\Module\Docker\Docker.psm1 -Force
. .\test\pester\\Utils.ps1

function Test-InvokeContainerImage
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
        $container = Invoke-ContainerImage -ImageName $ImageName -Isolation $isolation -Command @("cmd", "/c", "echo Worked") -PassThru
        $container | Should Not Be $null
        # TODO: How to test that output is "Worked"?
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

Describe "Invoke-ContainerImage - Test matrix of types and hosts." {
    It "Invoke_WindowsServerCore" -Skip:$(Test-Client -or Test-Nano) {
        { Test-InvokeContainerImage $global:WindowsServerCore $false } | Should Not Throw
    }

    It "Invoke_WindowsServerCore_Isolated" {
        { Test-InvokeContainerImage $global:WindowsServerCore $true } | Should Not Throw
    }

    It "Invoke_NanoServer" -Skip:$(Test-Client) {
        { Test-InvokeContainerImage $global:NanoServer $false } | Should Not Throw
    }

    It "Invoke_NanoServer_Isolated" {
        { Test-InvokeContainerImage $global:NanoServer $true } | Should Not Throw
    }
}

function TestInvokeWithDetach()
{
    param(
        [bool]
        $IsIsolated
    )
    
    $name = $global:DefaultContainerImageName
    $isolation = [Docker.PowerShell.Objects.IsolationType]::Process

    if ($IsIsolated)
    {
        $name = $global:DefaultIsolatedContainerImageName
        $isolation = [Docker.PowerShell.Objects.IsolationType]::Process
    }

    try
    {
        $container = Invoke-ContainerImage -Id "$name" -Isolation $isolation -Detach -Command @("cmd", "/c", "echo Worked") -PassThru
        $container | Should Not Be $null
        # TODO: Verify no output?

        $container | Wait-Container
    }
    finally
    {
        if ($container)
        {
            $container | Remove-Container
        }
    }
}

Describe "Invoke-ContainerImage -Detach does not wait." {
    It "Detach Default" -Skip:$(Test-Client) {
        { TestInvokeWithDetach $false } | Should Not Throw
    }

    It "Detach Default Isolated" -Skip:$(Test-Client) {
        { TestInvokeWithDetach $true } | Should Not Throw
    }
}

function TestRemoveAutomatically
{
    param(
        [bool]
        $IsIsolated
    )
    
    $name = $global:DefaultContainerImageName
    $isolation = [Docker.PowerShell.Objects.IsolationType]::Process

    if ($IsIsolated)
    {
        $name = $global:DefaultIsolatedContainerImageName
        $isolation = [Docker.PowerShell.Objects.IsolationType]::Process
    }

    $count = (Get-Container).Count
    Invoke-ContainerImage -Id "$name" -Isolation $isolation -RemoveAutomatically -Command @("cmd", "/c", "echo Worked") -PassThru
    $newCount = (Get-Container).Count

    $newCount | Should Be $count
}

Describe "Invoke-ContainerImage -RemoveAutomatically cleans up." {
    It "RemoveAutomatically Default" -Skip:$(Test-Client) {
        { TestRemoveAutomatically $false } | Should Not Throw
    }

    It "RemoveAutomatically Isolated" -Skip:$(Test-Client) {
        { TestRemoveAutomatically $true } | Should Not Throw
    }
}