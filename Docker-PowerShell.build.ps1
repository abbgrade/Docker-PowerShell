
task Restore {
    dotnet restore
}

task PublishStandard {
    dotnet publish .\src\Docker.PowerShell -o "$( Get-Location )\bin\Module\Docker" -f netstandard2.0
}

task PublishFramework {
    dotnet publish .\src\Docker.PowerShell -o "$( Get-Location )\bin\Module\Docker" -f net46
}

# TODO: Fix copy System.Runtime.dll to /bin
# task PublishCore {
#     dotnet publish .\src\Docker.PowerShell -o "$( Get-Location )\bin\Module\Docker" -f netcoreapp2.0
# }

task Test {
    Invoke-Pester -Script test/pester -PesterOption @{ IncludeVSCodeMarker = $true }
}

task Clean {
    @(
        ".\bin",
        ".\test\bin",
        ".\test\obj",
        ".\test\clr",
        ".\test\coreclr",
        ".\src\Docker.PowerShell\bin",
        ".\src\Docker.PowerShell\obj",
        ".\src\Docker.PowerShell\clr",
        ".\src\Docker.PowerShell\coreclr",
        ".\src\Docker.DotNet\src\Docker.DotNet\bin",
        ".\src\Docker.DotNet\src\Docker.DotNet\obj",
        ".\src\Docker.DotNet\src\Docker.DotNet\clr",
        ".\src\Docker.DotNet\src\Docker.DotNet\coreclr",
        ".\src\Docker.DotNet\src\Docker.DotNet.BasicAuth\bin",
        ".\src\Docker.DotNet\src\Docker.DotNet.BasicAuth\obj",
        ".\src\Docker.DotNet\src\Docker.DotNet.BasicAuth\clr",
        ".\src\Docker.DotNet\src\Docker.DotNet.BasicAuth\coreclr",
        ".\src\Docker.DotNet\src\Docker.DotNet.X509\bin",
        ".\src\Docker.DotNet\src\Docker.DotNet.X509\obj",
        ".\src\Docker.DotNet\src\Docker.DotNet.X509\clr",
        ".\src\Docker.DotNet\src\Docker.DotNet.X509\coreclr",
        ".\src\Tar\bin",
        ".\src\Tar\obj",
        ".\src\Tar\clr",
        ".\src\Tar\coreclr"
    ) | ForEach-Object { if ( Test-Path -Path $_ ) { Remove-item -Path $_ -Recurse } }
}

task UpdateHelp {
    Update-MarkdownHelp -Path .\src\Docker.PowerShell\Help
}

task CreateHelp {
    New-MarkdownHelp -Module Docker -OutputFolder .\src\Docker.Powershell\Help -ErrorAction SilentlyContinue
}