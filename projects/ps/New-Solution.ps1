param (
    [Parameter(Mandatory = $True, HelpMessage = 'The name of the department.')]
    [String]$department,
    
    [Parameter(Mandatory = $True, HelpMessage = 'The environment for this project.')]
    [String]$environment,

    [Parameter(Mandatory = $True, HelpMessage = 'The parent project name')]
    [string]$parentProject,

    [Parameter(Mandatory = $True, HelpMessage = 'The solution file.')]
    [string]$solutionParameterFile
)

function New-Environment{
    param (
        [string]$department,
        [string]$projectName,
        [string]$environment,
        [string]$parentProject,
        [string]$envtypeFolder,
        [string]$envtype
    )
    Write-Verbose "department                       : $department"
    Write-Verbose "projectName                      : $projectName"
    Write-Verbose "environment                      : $environment"
    Write-Verbose "parentProject                    : $parentProject"
    Write-Verbose "envtypeFolder                    : $envtypeFolder"
    Write-Verbose "envtype                          : $envtype"
    
    & "$PSScriptRoot\New-Resources.ps1" -department $department -projectName $projectName -environment $environment -parentProject $parentProject -envtypeFolder $envtypeFolder -envtype $envtype -Verbose
    $currentDirectory = Get-Item -Path $PSScriptRoot
    Write-Verbose "Current Directory                : $currentDirectory"
    $projectsDirectory = $currentDirectory.Parent.FullName
    Write-Verbose "Projects Directory               : $projectsDirectory"
    $projectsParameterFile = "{0}\{1}-{2}-{3}\projects.parameters.json" -f $projectsDirectory, $department, $projectName, $environment
    Write-Verbose "Projects Parameter File          : $projectsParameterFile"
    & "$PSScriptRoot\Set-Resources.ps1" -projectsParameterFile $projectsParameterFile -Verbose
}


$parameters = Get-Content -Path (Get-Item -Path $solutionParameterFile).FullName -Raw | ConvertFrom-JSON

$resources = $parameters.parameters.resources.value

$resource = $resources | Where-Object {$_.type -eq "envtypeFolder"}
$envtypeFolder = $resource.name

$resource = $resources | Where-Object {$_.type -eq "envtypes"}
$envtypes = $resource.names

$parentProjectName = $parentProject

foreach ($envtype in $envtypes) {    
    $projectName = $envtype
    Write-Verbose "============ Creating new environment of type $projectName ========="
    New-Environment -department $department -projectName $projectName -environment $environment -parentProject $parentProjectName -envtypeFolder $envTypeFolder -envtype $envtype
    $parentProjectName = "{0}-{1}-{2}" -f $department, $projectName, $environment
}

