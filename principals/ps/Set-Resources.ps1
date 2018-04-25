param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Set-Application {
    param
    (
        [string]$applicationName,
        [string]$applicationUri
    ) 

    $application = Get-AzureRmADApplication -DisplayNameStartWith $applicationName -ErrorAction SilentlyContinue
    if ($application -eq $null) {
        Write-Verbose "Creating new Azure AD Application"
        $application = New-AzureRmADApplication -DisplayName $applicationName -IdentifierUris $applicationUri
        Write-Verbose "Created new Azure AD Application"
    }
    else {
        Write-Verbose "Azure AD Application exists"
    }
    $applicationId = $application.ApplicationId
    $servicePrincipal = Get-AzureRmADServicePrincipal -SearchString $applicationName  -ErrorAction SilentlyContinue
    if ($servicePrincipal -eq $null) {
        Write-Verbose "Creating new Azure AD Service Principal"
        $servicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $applicationId
        Write-Verbose "Created new Azure AD Service Principal"
    }
    else {
        Write-Verbose "Azure AD Service Principal exists"
    }
    $servicePrincipalId = $servicePrincipal.Id

    $users = Get-AzureRmADServicePrincipal -SearchString $applicationName
    if ($users.Count -lt 1) {
        throw "$objType $searchString not found in the Azure Active Directory. Check the name."
    }
    if ($users.Count -gt 1) {
        throw "Found too many ${objType}s with name $searchString in the Azure Active Directory. Provide the full name to narrow the search."
    }

    Write-Verbose "Give this application Contributor rights to the resource groups."
    Write-Verbose "Application Id: $applicationId"
    Write-Verbose "ServicePrincipal Id: $servicePrincipalId"
    $props = @{ 
        applicationId      = $applicationId
        servicePrincipalId = $servicePrincipalId
    }
    return $props
}

function Set-Principal {
    param (
        [object]$principal
    )

    $principalIds = Set-Application -applicationName $principal.application.name `
        -applicationUri $principal.application.uri

    $principal.application.clientId = $principalIds.applicationId
    $principal.servicePrincipal.name = $principal.application.name
    $principal.servicePrincipal.id = $principalIds.servicePrincipalId
}

function Set-Principals {
    $principals = $parameters.parameters.resources.value | Where-Object {$_.type -eq "principal"} 
    foreach ($principal in $principals) {
        Set-Principal -principal $principal
    }    
}

$parameterFileName = "principals.parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-SetProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Set-Principals}