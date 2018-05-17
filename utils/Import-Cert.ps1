param (
    [Parameter (Mandatory = $true)]
    [string]$keyVaultName,

    [Parameter (Mandatory = $true)]
    [string]$certificateName,

    [Parameter (Mandatory = $false)]
    $certLocation = "cert:\currentuser\My"
)

function Get-CertInfo {
    param (
        [string]$keyVaultName,
        [string]$certLocation,
        [string]$certificateName
    )
    $cert = @{
        keyVaultName = $keyVaultName
        name         = $certificateName
        location     = $certLocation
        secret       = @{
            expiryTerm         = 2
            startdate          = Get-Date
            privateCertificate = "$($certificateName.Replace('.','-'))-certificate"
            publicCertificate  = "$($certificateName.Replace('.','-'))-certificate-public"
            password           = "$($certificateName.Replace('.','-'))-certificate-password"
        }
    }   
    return $cert 
}

$cert = Get-CertInfo -keyVaultName $keyVaultName `
                    -certLocation $certLocation `
                    -certificateName $certificateName
$secretName = $cert.secret.privateCertificate
$secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretName -ErrorAction SilentlyContinue
$secretPassword = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $cert.secret.password -ErrorAction SilentlyContinue
if ($secret -ne $null)
{
    Write-Verbose "secret $secretName exists in keyvault $keyVaultName"
    $rawCert = [System.Convert]::FromBase64String($secret.SecretValueText)
    $certFilePath = New-TemporaryFile
    $rawCert | Set-Content $certFilePath -Encoding Byte
    Import-PfxCertificate -FilePath $certFilePath `
                            -Password $secretPassword.SecretValue `
                            -CertStoreLocation $cert.location `
                            -Exportable
}else{
    Write-Verbose "secret $secretName does not exist in keyvault $keyVaultName"
}

