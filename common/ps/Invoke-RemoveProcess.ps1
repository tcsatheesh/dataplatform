param(
    [string]$projectsParameterFile,
    [string]$parameterFileName,
    [scriptblock]$procToRun
)


$commonPSFolder = (Get-Item -Path $PSScriptRoot).FullName
. "$commonPSFolder\Get-CommonFunctions.ps1"

Set-Subscription

$parameters = Get-ResourceParameters -parameterFileName $parameterFileName

& $procToRun -parameters $parameters
