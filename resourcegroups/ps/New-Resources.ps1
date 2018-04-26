param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function New-Resources {
    foreach ($resource in $parameters.parameters.resources.value) {
        Write-Verbose "Processing resource $($resource.Name)"
        $resource.name = Get-FormatedText -strFormat $resource.name
    }
}

$resourceType = (Get-Item -path $PSScriptRoot).Parent.Name

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$parameterFileName = "$resourceType.parameters.json"

& "$commonPSFolder\Invoke-NewProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType $resourceType `
    -parameterFileName $parameterFileName `
    -procToRun {New-Resources}
