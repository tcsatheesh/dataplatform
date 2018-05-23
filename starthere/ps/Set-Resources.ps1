param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,

    [Parameter(Mandatory = $True, HelpMessage = 'The user type to runas.')]
    [ValidateSet ("user-administrator", "subscription-owner", "keyvault-administrator", "manager", "vsts", "developer")]
    [String]$runas
)

function Set-Resource {
    param (
        [object]$resourceType
    )
    $psFolder = (Get-Item -Path "$PSScriptRoot\..\..\$resourceType\ps").FullName
    $newScript = ( Get-Item -Path "$psFolder\New-Resources.ps1").FullName
    $setScript = ( Get-Item -Path "$psFolder\Set-Resources.ps1").FullName
    Write-Verbose "Creating new resource parameter for $resourceType"
    # Write-Verbose "New script is $newScript"
    & $newScript -projectsParameterFile $projectsParameterFile 
    & $setScript -projectsParameterFile $projectsParameterFile    
}

function Set-Deploy {
    $deploy = $parameters.parameters.resources.value | Where-Object {$_.type -eq $runas}
    foreach ($resource in $deploy.resources) {
        Set-Resource -resourceType $resource
    }
}

$parameterFileName = "projects.parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-SetProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Set-Deploy}
