param (
    [String]$projectsParameterFile
)

$commonFolder = (Get-Item -Path "$PSScriptRoot\..\common\ps")

$principalsParameterFile = "principals.parameters.json"
$principalsParameters = & "$commonFolder\Get-ResourceParameters.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $principalsParameterFile

$projectsParameterFileName = "projects.parameters.json"
$projectsParameters = & "$commonFolder\Get-ResourceParameters.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $projectsParameterFileName

$clientSecretsParameterFile = "clientsecrets.parameters.json"
$clientSecretsParameters = & "$commonFolder\Get-ResourceParameters.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $clientSecretsParameterFile

$keyVaultParameterFile = "keyvaults.parameters.json"
$keyVaultParameters = & "$commonFolder\Get-ResourceParameters.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $keyVaultParameterFile

$props = @{
    projects      = $projectsParameters.parameters.resources.value
    principals    = $principalsParameters.parameters.resources.value
    clientSecrets = $clientSecretsParameters.parameters.resources.value
    keyVaults     = $keyVaultParameters.parameters.resources.value
}
return $props
