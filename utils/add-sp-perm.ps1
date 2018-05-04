$azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
$currentAzureContext = Get-AzureRmContext
$profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
Write-Debug ("Getting access token for tenant" + $currentAzureContext.Subscription.TenantId)
$token = $profileClient.AcquireAccessToken($currentAzureContext.Subscription.TenantId)

$authorization = "Bearer $($token.AccessToken)"

Write-Host "Access Token is $authorization"
$uri = "https://graph.windows.net/myorganization/servicePrincipals?api-version=1.6&$filter=appId eq '00000002-0000-0000-c000-000000000000'"

$headers = @{
    "authorization" = $authorization;
    "cache-control" = "no-chase";
}

$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $Headers

Write-Host $response