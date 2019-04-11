param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Get-WebhookUri {
    param(
        [string]$resourcename
    )
    $subscriptionId = Get-SubscriptionId
    $tenantId = (Get-ProjectParameter -type "tenant").id
    $client = Get-ApplicationParameter -type "applicationPrincipal" -godeep
    $clientId = $client.application.clientId
    $clientSecretName = $client.application.passwordSecretName
    $keyVaultName = Get-KeyVaultName -keyVaultType "appkeyvault"
    Write-Verbose "Key Vault name: $keyVaultName"
    $secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $clientSecretName
    $clientSecret = $secret.SecretValueText
    $resourceGroupName = Get-ResourceGroupName -resourceGroupTypeRef "app"
    $automationAccountName = $resourcename

    $parameters = @{
        "subscriptionId" = $subscriptionId
        "tenantId" = $tenantId
        "clientId" = $clientId
        "clientSecret" = $clientSecret
        "resourceGroupName" = $resourceGroupName
        "automationAccountName" = $automationAccountName
    }
    
    $val = Get-WebhookUriInternal   -subscriptionId $parameters.subscriptionId `
                                    -tenantId $parameters.tenantId `
                                    -clientId $parameters.clientId `
                                    -clientSecret $parameters.clientSecret `
                                    -resourceGroupName $parameters.resourceGroupName `
                                    -automationAccountName $parameters.automationAccountName
    return $val
}


function Get-WebhookUriInternal {
    param (
        [Parameter(Mandatory = $True, HelpMessage = 'Subscription id')]
        [String]$subscriptionId,
    
        [Parameter(Mandatory = $True, HelpMessage = 'Tenant id')]
        [String]$tenantId,
    
        [Parameter(Mandatory = $True, HelpMessage = 'Specify the client Id.')]
        [String]$clientId,
        
        [Parameter(Mandatory = $True, HelpMessage = 'Specify the client secret.')]
        [String]$clientSecret,
    
        [Parameter(Mandatory = $True, HelpMessage = 'Specify the resource to get access token for')]
        [String]$resourceGroupName,
    
        [Parameter(Mandatory = $True, HelpMessage = 'Specify the resource to get access token for')]
        [String]$automationAccountName
    )

    $url = "https://login.microsoftonline.com/{0}/oauth2/token"
    $resource = "https://management.azure.com/"
    $grant_type = "client_credentials"

    $body = @{
        'grant_type'    = $grant_type
        'resource'      = $resource
        'client_id'     = $clientId
        'client_secret' = $clientSecret
    
    }

    $uri = $url -f $tenantId
    $params = @{
        ContentType = 'application/x-www-form-urlencoded'
        Headers     = @{
            'accept' = 'application/json'
        }
        Method      = 'Post'
        URI         = $uri
        Body        = $body
    }

    $authZResponse = Invoke-RestMethod @params
    $access_token = $authZResponse.access_token

    $atmnurl = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Automation/automationAccounts/{2}/webhooks/generateUri?api-version=2015-10-31"

    $uri = $atmnurl -f $subscriptionId, $resourceGroupName, $automationAccountName
    $params = @{
        ContentType = "application/json"
        Headers     = @{
            "accept"        = "application/json"
            "Authorization" = "Bearer $access_token"
        }
        Method      = "Post"
        URI         = $uri    
    }

    $authZResponse = Invoke-RestMethod @params
    Write-Verbose "Webhook Uri is $authZResponse"
    return $authZResponse
}

function Get-Body {
    param (
        [object]$value
    )
    Write-Verbose "************* $value"
    $tenantId = (Get-ProjectParameter -type "tenant").id
    $analysisServicesName = Get-FormatedText -strFormat "{0}{1}{2}as01"
    
    $value.TenantId = $value.TenantId -f $tenantId
    $value.AnalysisServicesServer = $value.AnalysisServicesServer -f $analysisServicesName
    
    return $value
}

function Get-AuthUrl {
    param (
        [object]$resourceparam
    )
    $tenantId = (Get-ProjectParameter -type "tenant").id
    $val = $resourceparam.value -f $tenantId
    return $val
}

function Set-ResourceSpecificParameters {
    param (
        [object]$resource,
        [object]$resourceparam
    )
    if ($resourceparam.name -eq "body") {
        $val = Get-Body -value $resourceparam.value
    }
    elseif ($resourceparam.name -eq "url") {
        $atmnaccname = Get-FormatedText -strFormat $resourceparam.value
        $val = Get-WebhookUri -resourcename $atmnaccname
    }
    elseif ($resourceparam.name -eq "authUrl") {
        $val = Get-AuthUrl -resourceparam $resourceparam
    }
    else {
        throw "resource param $($resourceparam.name) not supported"
    } 
    return $val
}


$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\New-Resources.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name