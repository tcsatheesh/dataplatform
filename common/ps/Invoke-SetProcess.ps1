param(
    [string]$projectsParameterFile,
    [string]$parameterFileName,
    [scriptblock]$procToRun
)

$commonPSFolder = (Get-Item -Path $PSScriptRoot).FullName
& "$commonPSFolder\Set-Subscription.ps1" `
    -projectsParameterFile $projectsParameterFile

$parameters = & "$commonPSFolder\Get-ResourceParameters.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName

& $procToRun -parameters $parameters

& "$commonPSFolder\Update-ProjectParameters.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameters $parameters -parameterFileName $parameterFileName
