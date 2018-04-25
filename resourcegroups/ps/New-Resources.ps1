param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function New-ResourceGroupsParameters {
    foreach ($resourceGroup in $parameters.parameters.resources.value) {
        Write-Verbose "Processing resource group $($resourceGroup.Name)"
        $resourceGroup.name = Get-FormatedText -strFormat $resourceGroup.name
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$parameterFileName = "resourcegroups.parameters.json"

& "$commonPSFolder\Invoke-NewProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType "resourcegroups" `
    -parameterFileName $parameterFileName `
    -procToRun {New-ResourceGroupsParameters}
