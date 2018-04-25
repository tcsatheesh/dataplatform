param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName

& "$commonPSFolder\New-Resources.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType "hdinsights"
