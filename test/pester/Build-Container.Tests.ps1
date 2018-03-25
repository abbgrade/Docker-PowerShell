<#
.DESCRIPTION
    This script will test the basic build functionality.

#>

Import-Module .\bin\Module\Docker\Docker.psm1 -Force
. .\test\pester\Utils.ps1

function New-Dockerfile
{
    param(
        [string]
        [ValidateNotNullOrEmpty()]
        $BasePath,

        [string]
        [ValidateNotNullOrEmpty()]
        $ImageName
    )

    $filepath = Join-Path $BasePath "Dockerfile"
    Write-Debug "Creating dockerfile at path: '$filepath'."

    "FROM $ImageName" | Out-File -FilePath $filePath -Encoding utf8 -Append 
    "RUN echo test > test.txt" | Out-File -FilePath $filePath -Encoding utf8 -Append

    Write-Debug "Successfully created dockerfile."
}

function Test-ImageBuild
{
    param(
        [string]
        [ValidateNotNullOrEmpty()]
        $ImageName,

        [bool]
        $IsIsolated,

        [string]
        [ValidateNotNullOrEmpty()]
        $Tag
    )
	
    $basePath = New-TempTestPath
    New-Dockerfile $basePath $ImageName

    $isolation = [Docker.PowerShell.Objects.IsolationType]::Default
    if ($IsIsolated)
    {
        $isolation = [Docker.PowerShell.Objects.IsolationType]::HyperV
    }
    
    Write-Debug "Building image: '$Tag'"
    Build-ContainerImage -Path "$basePath" -Repository "$Tag" -SkipCache -Isolation $isolation
}

function Test-ImageBuilds
{
    param(
        [string]
        [ValidateNotNullOrEmpty()]
        $ImageName,

        [bool]
        $IsIsolated
    )

    $tag = "test"
    if ($IsIsolated)
    {
        $tag = "isolated" + $tag
    }

    $firstTag = $tag + "1"
    $secondTag = $tag + "2"

    try
    {
        # Test a level 1 build.
        $image = Test-ImageBuild "$ImageName" $IsIsolated "$firstTag"
        $image | Should Not Be $null

        # Test a second build based on the first.
        $image2 = Test-ImageBuild "$firstTag" $IsIsolated "$secondTag"
        $image2 | Should Not Be $null
    }
    finally
    {
        # Cleanup
        if ($image2)
        {
            $image2 | Remove-ContainerImage
        }

        if ($image)
        {
            $image | Remove-ContainerImage
        }
    }
}

Describe "Build-ContainerImage - Test matrix of types and hosts." {

    It "Use Type" {
        $type = Get-TypeData -TypeName "Docker.PowerShell"
        $type | Should Be 
    }

    It "WindowsServerCore_Image_Build" -Skip:$( Test-Client -or Test-Nano ) {
        { Test-ImageBuilds $global:WindowsServerCore $false } | Should Not Throw
    }

    It "WindowsServerCore_Isolated_Image_Build" {
        { Test-ImageBuilds $global:WindowsServerCore $true } | Should Not Throw
    }

    It "NanoServer_Image_Build" -Skip:$( Test-Client ) {
        { Test-ImageBuilds $global:NanoServer $false } | Should Not Throw
    }

    It "NanoServer_Isolated_Image_Build" {
        { Test-ImageBuilds $global:NanoServer $true } | Should Not Throw
    }
}