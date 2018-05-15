param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$resourceType = (Get-Item -Path $PSScriptRoot).Parent.Name

& "$commonPSFolder\Remove-Resources.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType $resourceType
