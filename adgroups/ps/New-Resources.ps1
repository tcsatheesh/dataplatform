param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function New-Resources {
    $adgroups = $parameters.parameters.resources.value
    foreach ($adgroup in $adgroups) {
        $adgroup.name = Get-FormatedText -strFormat $adgroup.name
        $adgroup.email = Get-FormatedText -strFormat $adgroup.email
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$parameterFileName = "adgroups.parameters.json"

& "$commonPSFolder\Invoke-NewProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType "adgroups" `
    -parameterFileName $parameterFileName `
    -procToRun {New-Resources}


