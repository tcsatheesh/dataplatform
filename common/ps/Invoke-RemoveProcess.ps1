param(
    [string]$projectsParameterFile,
    [string]$parameterFileName,
    [scriptblock]$procToRun
)


$commonPSFolder = (Get-Item -Path $PSScriptRoot).FullName
. "$commonPSFolder\Get-CommonFunctions.ps1"

& "$commonPSFolder\Set-Subscription.ps1" `
    -projectsParameterFile $projectsParameterFile

$parameters = & "$commonPSFolder\Get-ResourceParameters.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName

& $procToRun -parameters $parameters
