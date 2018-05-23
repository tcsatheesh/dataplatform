param(
    [string]$projectsParameterFile,
    [string]$resourceType,
    [string]$parameterFileName,
    [scriptblock]$procToRun
)

$commonPSFolder = (Get-Item -Path $PSScriptRoot).FullName
. "$commonPSFolder\Get-CommonFunctions.ps1"

$parameters = Get-TemplateParameters -resourceType $resourceType -parameterFileName $parameterFileName 

& $procToRun

Update-ProjectParameters -parameters $parameters -parameterFileName $parameterFileName

