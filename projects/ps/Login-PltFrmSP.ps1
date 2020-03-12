param(
    [Parameter(Mandatory = $False, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

if ([string]::IsNullOrEmpty($projectsParameterFile)) {
    $projectsParameterFile = "$PSScriptRoot\..\it-platform-d\projects.parameters.json"
    Write-Warning "Using the default development platform service principal"
}

if (-not (Test-Path -Path $projectsParameterFile)) {    
    throw "Project parameter file not found. You need to specify one."
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
. "$commonPSFolder\Get-CommonFunctions.ps1"

$principals = Get-ResourceParameters -parameterFileName "principals.parameters.json"
$projects = Get-ResourceParameters -parameterFileName "projects.parameters.json"

$platformDeploymentPrincipal = $principals.parameters.resources.value | Where-Object {$_.type -eq "platformDeploymentPrincipal"}
$applicationName = $platformDeploymentPrincipal.application.name
$applicationId = $platformDeploymentPrincipal.application.clientId

$tenant = $projects.parameters.resources.value | Where-Object {$_.type -eq "tenant"}
$tenantId = $tenant.id

$subscription = $projects.parameters.resources.value | Where-Object {$_.type -eq "subscription"}
$subscriptionId = $subscription.id

$certName = $applicationName
$subjectName = "CN={0}" -f $certName
$certStoreLocation = "cert:\currentuser\My"
$cert = Get-ChildItem -Path $certStoreLocation | Where-Object {$_.Subject -eq $subjectName} 
if ($null -eq $cert) {
    throw "Certificate not found in the current user store for application" 
}
$certificateThumbPrint = $cert.Thumbprint

Write-Verbose "Application Name: $applicationName"
Write-Verbose "Application Id: $applicationId"
Write-Verbose "Tenant Id: $tenantId"
Write-Verbose "Subscription Id: $subscriptionId"
Write-Verbose "Thumbprint: $certificateThumbPrint"

Connect-AzureRmAccount  -TenantId $tenantId -ApplicationId $applicationId -CertificateThumbprint $certificateThumbPrint -ServicePrincipal -Subscription $subscriptionId
Connect-AzureAD         -TenantId $tenantId -ApplicationId $applicationId -CertificateThumbprint $certificateThumbPrint
