param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,

    [Parameter(Mandatory = $False, HelpMessage = 'The application Type.')]
    $clientApplicationType = "applicationPrincipal"
)

$parameters = & "$PSScriptRoot\Get-ParameterSet.ps1" -projectsParameterFile $projectsParameterFile

$principal = $parameters.principals | Where-Object {$_.type -eq "principal" -and $_.subtype -eq "applicationPrincipal"}
$applicationName = $principal.application.name
$clientId = $principal.application.clientId
Write-Verbose "Application $applicationName client Id is $clientId"

$tenant = $parameters.projects | Where-Object {$_.type -eq "tenant"}
$tenantName = $tenant.name
$tenantId = $tenant.id
Write-Verbose "Tenant $tenantName tenant Id is $tenantId"

$clientSecret = $parameters.clientSecrets | Where-Object {$_.type -eq "password" -and $_.principalref -eq $clientApplicationType}
$keyVault = $parameters.keyVaults | Where-Object {$_.type -eq $clientSecret.keyVault.type}
$keyVaultName = $keyVault.name
$secretName = $principal.application.passwordSecretName
Write-Verbose "Keyvault is $keyVaultName and secretName is $secretName"
$clientSecret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretName


# This script will require the Web Application and permissions setup in Azure Active Directory
$ClientID       = $clientId             # Should be a ~35 character string insert your info here
$ClientSecret   = $clientSecret.SecretValueText         # Should be a ~44 character string insert your info here
$loginURL       = "https://login.microsoftonline.com/"
$tenantdomain   = $tenantName
$daterange            # For example, contoso.onmicrosoft.com

# Get an Oauth 2 access token based on client id, secret and tenant domain
$body       = @{grant_type="client_credentials";resource=$resource;client_id=$ClientID;client_secret=$ClientSecret}

$oauth      = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body

return $oauth
