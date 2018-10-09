param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

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

function Set-Resource {
    param (
        [object]$resource
    )

    if ($resource.type -eq "storageconnectionstring") {
        $secureSecretValue = Get-StorageConnectionString -resource $resource
    }
    elseif ($resource.type -eq "login") {
        $secret = New-Password
        $secureSecretValue = $secret.securePassword
    }
    elseif ($resource.type -eq "sqldbconnectionstring") {
        $secureSecretValue = Get-SqlConnectionString -resource $resource
    }
    elseif ($resource.type -eq "certificate") {
        $keyVaultName = Get-KeyVaultName -keyVaultType $resource.keyVaultType
        $secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $resource.certificatePasswordSecretName -ErrorAction SilentlyContinue
        if ( $secret -eq $null) {
            $secret = New-Password
            $secureSecretValue = $secret.securePassword
            $secretExpiryTerm = $resource.expiryTerm
            $secretExpiry = (Get-Date -Date $resource.startdate).AddYears($secretExpiryTerm)        
            $kyvlt = Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name $resource.certificatePasswordSecretName -SecretValue $secureSecretValue -Expires $secretExpiry
            Write-Verbose "Secret $($resource.certificatePasswordSecretName) added to the key vault $keyVaultName"
            $secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $resource.certificatePasswordSecretName -ErrorAction SilentlyContinue
        }
        else {
            Write-Verbose "Secret $($resource.certificatePasswordSecretName) exists in the key vault $keyVaultName"
        }
        $certificatePassword = $secret.SecretValue
        $certStoreLocation = "cert:\currentuser\My"
        $cert = Get-ChildItem -Path $certStoreLocation -DnsName $resource.certificateName
        if ($cert -eq $null) {
            throw "certificate $($resource.name) is missing in the $cerStoreLocation"
        }else {
            Write-Verbose "certificate $($resource.name) is in the $cerStoreLocation"
        }

        $certFilePath = New-TemporaryFile
        $exp = Export-Certificate -Cert $cert -FilePath $certFilePath -Type CERT -Force
        $rawCert = [System.Convert]::ToBase64String((Get-Content $certFilePath -Encoding Byte))
        $certificateValue = ConvertTo-SecureString -AsPlainText $rawCert -Force
        $secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $resource.certificatePublicSecretName -ErrorAction SilentlyContinue
        if ( $secret -eq $null) {
            $secretExpiryTerm = $resource.expiryTerm
            $secretExpiry = (Get-Date -Date $resource.startdate).AddYears($secretExpiryTerm)        
            $kyvlt = Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name $resource.certificatePublicSecretName -SecretValue $certificateValue -Expires $secretExpiry
            Write-Verbose "Secret $($resource.certificatePublicSecretName) added to the key vault $keyVaultName"
            $secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $resource.certificatePublicSecretName -ErrorAction SilentlyContinue
        }
        else {
            Write-Verbose "Secret $($resource.certificatePublicSecretName) exists in the key vault $keyVaultName"
        }


        $certFilePath = New-TemporaryFile
        $exp = Export-PfxCertificate -Cert $cert -FilePath $certFilePath -Password $certificatePassword -Force
        $rawCert = [System.Convert]::ToBase64String((Get-Content $certFilePath -Encoding Byte))
        $certificateValue = ConvertTo-SecureString -AsPlainText $rawCert -Force
        $secureSecretValue = $certificateValue
        $resource.certificateThumbprint = $cert.Thumbprint        
    }
    elseif ($resource.type -eq "value") {
        $secureSecretValue = ConvertTo-SecureString -AsPlainText $resource.secretValue -Force
        $resource.secretValue = ""
    }

    $keyVaultName = Get-KeyVaultName -keyVaultType $resource.keyVaultType
    $secretExpiryTerm = $resource.expiryTerm
    $secretExpiry = (Get-Date -Date $resource.startdate).AddYears($secretExpiryTerm)
    $secretCredential = New-Object System.Management.Automation.PSCredential ($resource.name, $secureSecretValue)
    $secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretCredential.UserName -ErrorAction SilentlyContinue
    if ( $secret -eq $null) {
        $kyvlt = Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretCredential.UserName -SecretValue $secretCredential.Password -Expires $secretExpiry -ErrorAction SilentlyContinue
        if ($kyvlt -eq $null){
            Write-Verbose "Secret $($secretCredential.UserName) not added to the key vault $keyVaultName. $kyvlt"
        }
        else {
            Write-Verbose "Secret $($secretCredential.UserName) added to the key vault $keyVaultName"
        }
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

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName
