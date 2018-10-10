param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Set-Resource2 {
    param (
        [object]$resourceType
    )
    $psFolder = (Get-Item -Path "$PSScriptRoot\..\..\$resourceType\ps").FullName

    $newScript = ( Get-Item -Path "$psFolder\New-Resources.ps1").FullName
    Write-Verbose "************** Creating new resourceType $resourceType *************"
    & $newScript -projectsParameterFile $projectsParameterFile

    $setScript = ( Get-Item -Path "$psFolder\Set-Resources.ps1").FullName
    Write-Verbose "************** Setting resourceType $resourceType *******************"
    & $setScript -projectsParameterFile $projectsParameterFile    
}

function Set-Resources2 {
    param (
        [object]$parameters
    )
    $environmentToDeploy = $parameters.parameters.resources.value | Where-Object {$_.type -eq "envtype"}
    $deploy = $parameters.parameters.resources.value | Where-Object {$_.type -eq $environmentToDeploy.value}
    foreach ($resource in $deploy.resources) {
        Set-Resource2 -resourceType $resource.resourceType
    }
}

$parameters = Get-Content -Path (Get-Item -Path $projectsParameterFile).FullName -Raw | ConvertFrom-JSON

Set-Resources2 -parameters $parameters