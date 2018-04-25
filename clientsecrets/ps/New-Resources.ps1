param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function New-ClientSecretParameter {
    param(
        [object]$resource
    )
}

function New-ClientSecretParameters {
    foreach ($resource in $parameters.parameters.resources.value) {
        New-ClientSecretParameter -resource $resource
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$parameterFileName = "clientsecrets.parameters.json"

& "$commonPSFolder\Invoke-NewProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType "clientsecrets" `
    -parameterFileName $parameterFileName `
    -procToRun {New-ClientSecretParameters}
