
task Restore {
    dotnet restore
}

task Build {
    dotnet build --output "$( Get-Location )\src\Docker.PowerShell\clr"
}

task Test {
    Invoke-Pester -Script test/pester -PesterOption @{ IncludeVSCodeMarker = $true }
}

task Clean {
    @(
        ".\test\bin",
        ".\test\obj",
        ".\test\cls",
        ".\src\Docker.PowerShell\bin",
        ".\src\Docker.PowerShell\obj",
        ".\src\Docker.PowerShell\cls",
        ".\src\Docker.DotNet\src\Docker.DotNet\bin",
        ".\src\Docker.DotNet\src\Docker.DotNet\obj",
        ".\src\Docker.DotNet\src\Docker.DotNet\clr",
        ".\src\Docker.DotNet\src\Docker.DotNet.BasicAuth\bin",
        ".\src\Docker.DotNet\src\Docker.DotNet.BasicAuth\obj",
        ".\src\Docker.DotNet\src\Docker.DotNet.BasicAuth\clr",
        ".\src\Docker.DotNet\src\Docker.DotNet.X509\bin",
        ".\src\Docker.DotNet\src\Docker.DotNet.X509\obj",
        ".\src\Docker.DotNet\src\Docker.DotNet.X509\clr",
        ".\src\Tar\bin",
        ".\src\Tar\obj",
        ".\src\Tar\clr"
    ) | ForEach-Object { if ( Test-Path -Path $_ ) { Remove-item -Path $_ -Recurse -Verbose } }
}

task UpdateHelp {
    Update-MarkdownHelp -Path .\src\Docker.PowerShell\Help
}