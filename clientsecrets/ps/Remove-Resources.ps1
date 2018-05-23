param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)
function Remove-ClientSecret {
    param
    (
        [string]$applicationName
    ) 
    $application = Get-AzureRmADApplication -DisplayNameStartWith $applicationName -ErrorAction SilentlyContinue
    if ($application -eq $null) {
        throw "Application $applicationName not found in Azure AD. Create it first"
    }
    else {
        Write-Verbose "Azure AD Application exists"
    }

    $appCreds = Get-AzureRmADAppCredential -ApplicationId $application.ApplicationId -ErrorAction SilentlyContinue
    if ($appCreds -ne $null) {
        Write-Verbose "Removing existing Azure AD Application credential."
        $appCreds | ForEach-Object {Remove-AzureRmADAppCredential -ApplicationId $application.ApplicationId -KeyId $_.KeyId -Force}
        Write-Verbose "Removed Azure AD Application credential."
    }
}

function Get-Principal {
    param (
        [string]$principalref
    )
    $parameterFileName = "principals.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    $resource = $parameters.parameters.resources.value | Where-Object {$_.type -eq "principal" -and $_.subtype -eq $principalref}
    Write-Verbose "Got principal $($resource.application.name) for principalref $principalref"
    return $resource
}

function Remove-ClientSecrets {
    $resources = $parameters.parameters.resources.value 
    foreach ($resource in $resources) {
        $principalref = $resource.principalref
        $principal = Get-Principal -principalref $principalref    
        Remove-ClientSecret -applicationName $principal.application.name
    }
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-RemoveProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Remove-ClientSecrets}