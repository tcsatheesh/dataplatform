param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Set-Application {
    param
    (
        [string]$applicationName,
        [securestring]$clientSecret,
        [int]$secretduration
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

    $endDate = (Get-Date).AddYears($secretduration)    
    Write-Verbose "Creating Azure AD Application credential"
    $appCred = New-AzureRmADAppCredential -ApplicationId $application.ApplicationId -Password $clientSecret -EndDate $endDate
    Write-Verbose "Created Azure AD Application credential"

    $props = @{ 
        applicationId      = $applicationId
        servicePrincipalId = $servicePrincipalId
    }
    return $props
}

function Set-PrincipalCertificate {
    param(
        [string]$applicationName,
        [int]$certificateDuration,
        [string]$certificateSecretValueText,
        [securestring]$certificatePassword
    )
    if ($certificateSecretValue -eq $null) {
        $certificateName = $applicationName
        $certName = $certificateName
        $certStoreLocation = "cert:\currentuser\My"

        $cert = Get-ChildItem -Path $certStoreLocation -DnsName $certName
        if ($cert -eq $null) {
            Write-Verbose "Certificate does not exist in the local cert store"
            $certStartDate = (Get-Date).Date
            $certEndDate = $certStartDate.AddYears($certificateDuration)    
            $cert = New-SelfSignedCertificate -DnsName $certName -CertStoreLocation $certStoreLocation `
                -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
                -KeySpec KeyExchange -NotAfter $certEndDate -NotBefore $certStartDate
        }
        else {
            Write-Verbose "Certificate exists in the local cert store"        
        }
        $cert = Get-ChildItem -Path $certStoreLocation -DnsName $certName
        $certStartDate = $cert.NotBefore
        $certEndDate = $cert.NotAfter   
        $certThumbprint = $cert.Thumbprint
        $certFolder = [System.IO.Path]::GetTempPath()
        $certFilePath = "$certFolder$certificateName.pfx"

        $exp = Export-PfxCertificate -Cert $cert -FilePath $certFilePath -Password $certificatePassword -Force

        $certificatePFX = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certFilePath, $certificatePassword)
        $credential = [System.Convert]::ToBase64String($certificatePFX.GetRawCertData())
    }
    else {
        $credential = $certificateSecretValueText
    }
    $keyId = [guid]::NewGuid().ToString("N")

    $objectid = (Get-AzureADApplication -SearchString $applicationName).ObjectId
    Write-Verbose "Object ID for Application $applicationName is $objectId"
    $keyCred = New-AzureADApplicationKeyCredential -ObjectId $objectid `
        -CustomKeyIdentifier $keyId `
        -StartDate $certStartDate -EndDate $certEndDate `
        -Type AsymmetricX509Cert -Usage Verify -Value $credential
    $props = @{
        FilePath   = $certFilePath
        Thumbprint = $certThumbprint
    }
    return $props
}

function Set-Principal {
    param (
        [object]$principal,
        [object]$resource
    )
    Write-Verbose "Processing $($principal.application.name)"
 
    Write-Verbose "Secret for $($principal.application.name) does not exist in the keyvault. Creating new..."
    $secret = New-Password
    $secretValue = $secret.securePassword
    
    $keyVaultName = Get-KeyVaultName -keyVaultType $resource.keyvault.type
    if ($resource.type -eq "password") {
        $secretName = $principal.application.passwordSecretName
        $secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretName -ErrorAction SilentlyContinue
        if ($secret -eq $null) {
            Write-Verbose "Secret for $secretName does not exist in the keyvault. Creating..."
        }
        else {
            Write-Verbose "Secret for $secretName exists in the keyvault"
            $secretValue = $secret.SecretValue
        }
         
        $principalIds = Set-Application -applicationName $principal.application.name `
            -clientSecret $secretValue `
            -secretduration $resource.duration
        Set-SecretValueInKeyVault `
            -keyvaultName $keyVaultName `
            -secretName $secretName -secretValue $secretValue `
            -startdate $resource.keyvault.startdate `
            -expiryTerm $resource.keyvault.expiryTerm
    }
    elseif ($resource.type -eq "certificate") {
        $certificateSecretName = $principal.application.certificateSecretName

        $certificateSecret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $certificateSecretName -ErrorAction SilentlyContinue
        if ($certificateSecret -eq $null) {
            Write-Verbose "certificateSecret for $certificateSecretName does not exist in the keyvault. Creating..."
            $certificatePasswordSecretValue = $secretValue
        }
        else {
            Write-Verbose "certificateSecret for $certificateSecretName exists in the keyvault"
            $certificateSecretValueText = $certificateSecret.SecretValueText
        }

        $certificatePasswordSecretName = $principal.application.certificatePasswordSecretName
        $certificatePasswordSecret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $certificatePasswordSecretName -ErrorAction SilentlyContinue
        if ($certificatePasswordSecret -eq $null) {
            Write-Verbose "certificatePasswordSecret for $certificatePasswordSecretName does not exist in the keyvault. Creating..."
        }
        else {
            Write-Verbose "certificatePasswordSecret for $certificatePasswordSecretName exists in the keyvault"
            $certificatePasswordSecretValue = $certificatePasswordSecret.SecretValue
        }
             
        $principalCertificate = Set-PrincipalCertificate `
            -applicationName $principal.application.name `
            -certificateDuration $resource.certificate.duration `
            -certificateSecretValueText $certificateSecretValueText `
            -certificatePassword $certificatePasswordSecretValue
        $resource.thumbprint = $principalCertificate.Thumbprint

        Set-SecretValueInKeyVault `
            -keyvaultName $keyVaultName `
            -secretName $certificatePasswordSecretName -secretValue $secretValue `
            -startdate $resource.keyvault.startdate `
            -expiryTerm $resource.keyvault.expiryTerm

        $rawCert = [System.Convert]::ToBase64String((Get-Content $principalCertificate.FilePath -Encoding Byte))
        $certificateValue = ConvertTo-SecureString -AsPlainText $rawCert -Force

        Set-SecretValueInKeyVault `
            -keyvaultName $keyVaultName `
            -secretName $certificateSecretName -secretValue $certificateValue `
            -startdate $resource.keyvault.startdate `
            -expiryTerm $resource.keyvault.expiryTerm
            
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

function Set-SecretValueInKeyVault {
    param(
        [string]$keyVaultName,
        [string]$secretName,
        [securestring]$secretValue,
        [object]$startdate,
        [int]$expriryTerm
    )
    $secretExpiry = (Get-Date -Date $startdate).AddYears($expiryTerm)
    $secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretName -ErrorAction SilentlyContinue
    if ($secret -eq $null) {
        $kyvlt = Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretName -SecretValue $secretValue -Expires $secretExpiry
        Write-Verbose "Secret $secretName added to the key vault $keyVaultName"
    }
    else {
        Write-Verbose "Secret $secretName already in the key vault $keyVaultName"
    }
}

function Set-ClientSecrets {
    $resources = $parameters.parameters.resources.value 
    foreach ($resource in $resources) {
        $principalref = $resource.principalref
        $principal = Get-Principal -principalref $principalref    
        Set-Principal -principal $principal -resource $resource        
    }    
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-SetProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Set-ClientSecrets}