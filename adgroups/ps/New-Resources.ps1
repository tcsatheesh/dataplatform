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

& "$commonPSFolder\Invoke-NewProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name `
    -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json" `
    -procToRun {New-Resources}


