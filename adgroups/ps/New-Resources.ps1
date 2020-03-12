param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function New-Resource {
    param (
        [object]$resource
    )
    $resource.name = Get-FormatedText -strFormat $resource.name
    $group = Get-AzureRmADGroup -DisplayName $resource.name -ErrorAction SilentlyContinue
    if ($group -ne $null) {
        $resource.id = $group.Id.Guid
        $resource.email = $group.MailNickname    
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"


