param (
    [Parameter(Mandatory = $True, HelpMessage = 'The name of the department.')]
    [String]$department,
    
    [Parameter(Mandatory = $True, HelpMessage = 'The environment for this project.')]
    [String]$environment,

    [Parameter(Mandatory = $True, HelpMessage = 'The solution file.')]
    [string]$solutionParameterFile
)

function Remove-Environment{
    param (
        [string]$department,
        [string]$projectName,
        [string]$environment,
        [Switch]$removeProjectFolder
    )
    Write-Verbose "department                       : $department"
    Write-Verbose "projectName                      : $projectName"
    Write-Verbose "environment                      : $environment"
    
    $currentDirectory = Get-Item -Path $PSScriptRoot
    Write-Verbose "Current Directory                : $currentDirectory"
    $projectsDirectory = $currentDirectory.Parent.FullName
    Write-Verbose "Projects Directory               : $projectsDirectory"
    $projectsParameterFile = "{0}\{1}-{2}-{3}\projects.parameters.json" -f $projectsDirectory, $department, $projectName, $environment
    Write-Verbose "Projects Parameter File          : $projectsParamterFile"
    & "$PSScriptRoot\Remove-Resources.ps1" -projectsParameterFile $projectsParameterFile -removeProjectFolder -Verbose
}


$parameters = Get-Content -Path (Get-Item -Path $solutionParameterFile).FullName -Raw | ConvertFrom-JSON

$resources = $parameters.parameters.resources.value

$resource = $resources | Where-Object {$_.type -eq "envtypeFolder"}
$envtypeFolder = $resource.name

$resource = $resources | Where-Object {$_.type -eq "envtypes"}
$envtypes = $resource.names

[array]::Reverse($envtypes)

foreach ($envtype in $envtypes) {    
    $projectName = $envtype
    Write-Verbose "============ Removing environment of type $projectName ========="
    Remove-Environment -department $department -projectName $projectName -environment $environment -removeProjectFolder    
}

