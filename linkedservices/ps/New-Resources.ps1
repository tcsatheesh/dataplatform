param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Store-ParametersToFile { 
    param (
        [string]$resourceName,
        [object]$parameters,
        [string]$parameterFileName
    )
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $destinationPath = "$projectFolder\$resourceName"
    $destinationPath = New-Item -Path $destinationPath -ItemType Directory -Force
    $destinationPath = "$destinationPath\$parameterFileName"
    Write-Verbose "Destination Path is $destinationPath"
    $parameters | ConvertTo-JSON -Depth 10 | Out-File -filepath $destinationPath -Force -Encoding utf8
    Write-Verbose "Linked services parameter file created at: $destinationPath"
}

function Set-AccessPolicy {
    param (
        [object]$resource,
        [string]$keyVaultName
    )
    $dataFactoryName = Get-ValueFromResource `
        -resourceType "adfs" `
        -typeFilter $resource.dataFactoryNameRef `
        -property "name"
    $servicePrincipal = Get-AzureRmADServicePrincipal -SearchString $dataFactoryName
    if ($servicePrincipal -eq $null) {
        throw "servicePrincipal for dataFactory $dataFactoryName is null"
    }
    Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $servicePrincipal.Id -PermissionsToSecrets get
}

function Get-KeyVaultLinkedService {
    param (
        [object]$resource,
        [object]$linkedService
    )

    $keyVaultName = Get-ValueFromResourceRef -parameters $resource.parameters -type "keyvault"
    $baseUrl = $linkedService.properties.typeProperties.baseUrl -f $keyVaultName    
    $linkedService.properties.typeProperties.baseUrl = $baseUrl

    Set-AccessPolicy -resource $resource -keyVaultName $keyVaultName
    return $linkedService
}

function Get-StorageLinkedService {
    param (
        [object]$resource,
        [object]$linkedService
    )
    $keyVaultName =  Get-ValueFromResourceRef -parameters $resource.parameters -type "keyvault"    
    $secretName =  Get-ValueFromResourceRef  -parameters $resource.parameters -type "connectionStringSecretName" -subtype "storage"
    
    if ($secretName -eq $null){
        throw "Secret name for $storageAccountName is null"
    }

    $linkedService.properties.typeProperties.connectionString.store.referenceName = $keyVaultName
    $linkedService.properties.typeProperties.connectionString.secretName = $secretName 

    return $linkedService
}

function Get-ADLStoreLinkedService {
    param (
        [object]$resource,
        [object]$linkedService
    )

    $adlStoreResourceGroupName = Get-ValueFromResourceRef -parameters $resource.parameters -type "adlstoreResourceGroupName"
    $adlStoreName = Get-ValueFromResourceRef -parameters $resource.parameters -type "adlstore"    
    $tenantDomainName = Get-ValueFromResourceRef -parameters $resource.parameters -type "tenant"
    $appApplicationId = Get-ValueFromResourceRef -parameters $resource.parameters -type "applicationPrincipal"
    $appServicePrincipalId = Get-ValueFromResourceRef -parameters $resource.parameters -type "servicePrincipal"
    $keyVaultName =  Get-ValueFromResourceRef -parameters $resource.parameters -type "keyvault"
    $subscriptionId = Get-ValueFromResourceRef -parameters $resource.parameters -type "subscriptionId"
    $secretName = Get-ValueFromResourceRef -parameters $resource.parameters -type "secretName"

    $dataLakeStoreUri = "adl://{0}.azuredatalakestore.net/" -f $adlStoreName    
    $linkedService.properties.typeProperties.dataLakeStoreUri = $dataLakeStoreUri
    $linkedService.properties.typeProperties.servicePrincipalId = $appApplicationId
    $linkedService.properties.typeProperties.servicePrincipalKey.store.referenceName = $keyVaultName
    $linkedService.properties.typeProperties.servicePrincipalKey.secretName = $secretName 
    $linkedService.properties.typeProperties.tenant = $tenantDomainName
    $linkedService.properties.typeProperties.subscriptionId = $subscriptionId
    $linkedService.properties.typeProperties.resourceGroupName = $adlStoreResourceGroupName
    
    return $linkedService
}

function Get-SqlLinkedService {
    param (
        [object]$resource,
        [object]$linkedService
    )

    $keyVaultName =  Get-ValueFromResourceRef -parameters $resource.parameters -type "keyvault"
    $secretName =  Get-ValueFromResourceRef  -parameters $resource.parameters -type "connectionStringSecretName"
    
    if ($secretName -eq $null){
        throw "Secret name for $storageAccountName is null"
    }

    $linkedService.properties.typeProperties.connectionString.store.referenceName = $keyVaultName
    $linkedService.properties.typeProperties.connectionString.secretName = $secretName 

    return $linkedService
}

function Get-ADLALinkedService {
    param (
        [object]$resource,
        [object]$linkedService
    )

    $adlaResourceGroupName = Get-ValueFromResourceRef -parameters $resource.parameters -type "adlaResourceGroupName"
    $adlAccountName = Get-ValueFromResourceRef -parameters $resource.parameters -type "adlAccountName"    
    $tenantDomainName = Get-ValueFromResourceRef -parameters $resource.parameters -type "tenant"
    $appApplicationId = Get-ValueFromResourceRef -parameters $resource.parameters -type "applicationPrincipal"
    $appServicePrincipalId = Get-ValueFromResourceRef -parameters $resource.parameters -type "servicePrincipal"
    $keyVaultName =  Get-ValueFromResourceRef -parameters $resource.parameters -type "keyvault"
    $subscriptionId = Get-ValueFromResourceRef -parameters $resource.parameters -type "subscriptionId"
    $secretName = Get-ValueFromResourceRef -parameters $resource.parameters -type "secretName"

    $linkedService.properties.typeProperties.accountName = $adlAccountName     
    $linkedService.properties.typeProperties.servicePrincipalId = $appApplicationId
    $linkedService.properties.typeProperties.servicePrincipalKey.store.referenceName = $keyVaultName
    $linkedService.properties.typeProperties.servicePrincipalKey.secretName = $secretName 
    $linkedService.properties.typeProperties.tenant = $tenantDomainName
    $linkedService.properties.typeProperties.subscriptionId = $subscriptionId
    $linkedService.properties.typeProperties.resourceGroupName = $adlaResourceGroupName
    
    return $linkedService
}

function New-Resource {
    param (
        [object]$resource
    )    
    $sourcePath = "$PSScriptRoot\..\templates\$($resource.templateFileName)"
    Write-Verbose "Getting linked service configuration template from $sourcePath" 
    $linkedService = Get-Content -Path $sourcePath -Raw | ConvertFrom-JSON

    $type = $resource.type
    switch ( $type )
    {
        "keyvault" { $linkedService = Get-KeyVaultLinkedService -resource $resource -linkedService $linkedService}
        "storage" { $linkedService = Get-StorageLinkedService -resource $resource -linkedService $linkedService}
        "adlstore" { $linkedService = Get-ADLStoreLinkedService -resource $resource -linkedService $linkedService}
        "adla" { $linkedService = Get-ADLALinkedService -resource $resource -linkedService $linkedService}
        "sqldb" { $linkedService = Get-SqlLinkedService -resource $resource -linkedService $linkedService}
        "default" { throw "hmmm... you need to add this type $type"}        
    }
    
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $destinationPath = "$projectFolder\linkedservices"
    $path = New-Item -Path $destinationPath -ItemType Directory -Force
    $desitinationFile = "$destinationPath\$($resource.templateFileName)"
    Write-Verbose "Writing $tempConfigFile with link service details"
    $linkedService | ConvertTo-JSON -Depth 10| Out-File -filepath $desitinationFile -Force
    Write-Verbose "Created linked service configuration $desitinationFile"
}

function New-Resources {
    param (
        [object]$parameters
    )
    $resources = $parameters.parameters.resources.value
    foreach ($resource in $resources) {
        if (($resource.enabled -eq $null) -or ($resource.enabled -eq $true)) {
            Write-Verbose "Processing $($resource.type)"
            New-Resource -resource $resource
        }
        else
        {
            Write-Verbose "Skipping deployment of $($resource.name)"
        }
    }
}


$commonPSFolder = (Get-Item -Path $PSScriptRoot).FullName
. "$commonPSFolder\Get-CommonFunctions.ps1"

$linkedServiceParametersFile = "$PSScriptRoot\..\templates\linkedservices.parameters.json"
$parameters = Get-Content $linkedServiceParametersFile -Raw | ConvertFrom-Json
New-Resources -parameters $parameters

$parameterFileName = (Get-Item -Path $linkedServiceParametersFile).Name

Store-ParametersToFile `
 -resourceName "linkedservices" `
 -parameters $parameters `
 -parameterFileName $parameterFileName