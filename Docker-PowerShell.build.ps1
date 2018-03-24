task Build {
    exec {

    }
}

task Restore {
    dotnet restore
}

task Clean {
    @(
        ".\test\bin",
        ".\test\obj",
        ".\src\Docker.PowerShell\bin",
        ".\src\Docker.PowerShell\obj"
    ) | ForEach-Object { if ( Test-Path -Path $_ ) { Remove-item -Path $_ -Recurse -Verbose } }
}