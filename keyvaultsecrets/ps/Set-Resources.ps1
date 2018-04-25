param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Get-ValueFromResource {
    param(
        [string]$resourceType,
        [string]$property,
        [string]$typeFilter,
        [string]$subtypeFilter
    )
    
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $itemPath = "$projectFolder\$resourceType.parameters.json"
    $parameters = Get-Content -Path $itemPath -Raw | ConvertFrom-Json
    
    if ([String]::IsNullOrEmpty($subtypeFilter)) {
        $item = $parameters.parameters.resources.value | Where-Object {$_.type -eq $typeFilter}
    }
    else {
        $item = $parameters.parameters.resources.value | `
            Where-Object {$_.type -eq $typeFilter -and $_.subtype -eq $subtypeFilter}
    }

    if ($item -eq $null) {
        throw "Item cannot be null here for type $type. 
         ResourceType $resourceType 
         Type Filter $typeFilter
         Property $property
         Sub Type Filter $subtypeFilter
        "
    }

    $props = $property.Split(".")
    foreach ($prop in $props) {
        $item = $item.$prop
        if ($item -eq $null) {
            throw "Item cannot be null for $prop"
        }
    }
    $val = $item
    return $val 
}

function Get-ValueFromResourceRef {
    param (
        [object]$parameters,
        [string]$type
    )
    $parameter = $parameters | Where-Object {$_.type -eq $type}
    $val = Get-ValueFromResource `
        -resourceType $parameter.ref.resourceType `
        -typeFilter $parameter.ref.typeFilter `
        -property $parameter.ref.property `
        -subtypeFilter $parameter.ref.subtypeFilter
    return $val
}

function Get-StorageConnectionString {
    param (
        [object]$resource
    )
    $storageAccountResourceGroupName = Get-ValueFromResourceRef -parameters $resource.parameters -type "storageAccountResourceGroupName"
    $storageAccountName = Get-ValueFromResourceRef -parameters $resource.parameters -type "storageAccountName"
    $storageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $storageAccountResourceGroupName -Name $storageAccountName)[0].Value
    $connectionString = "DefaultEndpointsProtocol=https;AccountName={0};AccountKey={1}" -f $storageAccountName, $storageAccountKey
    $secretValue = ConvertTo-SecureString -AsPlainText $connectionString -Force
    return $secretValue
}

function Get-SqlConnectionString {
    param(
        [object]$resource
    )
    $sqlServer = $resource.parameters | Where-Object {$_.name -eq "sqlServerName"}
    $sqlServerName = $sqlServer.value
    $sqlDatabase = $resource.parameters | Where-Object {$_.name -eq "sqlDatabaseName"}
    $sqlDatabaseName = $sqlDatabase.value    
    $account = $resource.parameters | Where-Object {$_.name -eq "account"}
    $sqlLoginName = $account.value
    $keyVaultName = Get-KeyVaultName -keyVaultType $resource.keyVaultType
    $secretName = $resource.name
    $secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretName
    $sqlLoginPassword = $secret.SecretValueText
    $connectionString = "Data Source=tcp:{0}.database.windows.net,1433;Initial Catalog={1};User ID={2};Password={3};Integrated Security=False;Encrypt=True;Connect Timeout=30" `
        -f $sqlServerName, $sqlDatabaseName, $sqlLoginName, $sqlLoginPassword
    $secretValue = ConvertTo-SecureString -AsPlainText $connectionString -Force

    return $secretValue    
}

function Get-KeyVaultName {
    param (
        [string]$keyVaultType
    )
    $commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
    $parameterFileName = "keyvaults.parameters.json"
    $parameters = & "$commonPSFolder\Get-ResourceParameters.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName
    $resource = $parameters.parameters.resources.value | Where-Object {$_.type -eq $keyVaultType}
    $keyVaultName = $resource.name
    return $keyVaultName
}

function Set-Secret {
    param (
        [object]$resource
    )

    if ($resource.type -eq "storageconnectionstring") {
        $secureSecretValue = Get-StorageConnectionString -resource $resource
    }
    elseif ($resource.type -eq "login") {
        $commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
        $secret = & "$commonPSFolder\New-Password.ps1"
        $secureSecretValue = $secret.securePassword
    }
    elseif ($resource.type -eq "sqldbconnectionstring") {
        $secureSecretValue = Get-SqlConnectionString -resource $resource
    }
    elseif ($resource.type -eq "value") {
        $secureSecretValue = ConvertTo-SecureString -AsPlainText $resource.secretValue -Force
    }

    $keyVaultName = Get-KeyVaultName -keyVaultType $resource.keyVaultType
    $secretExpiryTerm = $resource.expiryTerm
    $secretExpiry = (Get-Date -Date $resource.startdate).AddYears($secretExpiryTerm)
    $secretCredential = New-Object System.Management.Automation.PSCredential ($resource.name, $secureSecretValue)   
    $secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretCredential.UserName -ErrorAction SilentlyContinue
    if ( $secret -eq $null) {
        $kyvlt = Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretCredential.UserName -SecretValue $secretCredential.Password -Expires $secretExpiry
        Write-Verbose "Secret $($secretCredential.UserName) added to the key vault $keyVaultName"
    }
    elseif ($resource.updateSecret) {
        Write-Verbose "Update specified for the secret $($secretCredential.UserName) in the key vault $keyVaultName"
        $kyvlt = Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretCredential.UserName -SecretValue $secretCredential.Password -Expires $secretExpiry
        Write-Verbose "Secret $($secretCredential.UserName) updated to the key vault $keyVaultName"
    }
    else {
        Write-Verbose "Secret $($secretCredential.UserName) exists in the key vault $keyVaultName."
    }
}

function Set-Secrets {
    foreach ($resource in $parameters.parameters.resources.value) {
        Write-Verbose "Processing secret $($resource.name)"
        Set-Secret -resource $resource
    }
}

$parameterFileName = "keyvaultsecrets.parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-SetProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Set-Secrets}
