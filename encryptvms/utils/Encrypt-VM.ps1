param (
    [string]$nothing
)

$ResourceGroupName = "it-iac-d-vms-rg"
$VMName = "itiacdvm01"

$keyVaultResourceGroupName = "it-iac-d-app-rg"
$keyVaultName = "itiacdnekvltacc"
$keyEncryptionKeyName = "it-iac-d-vm-key-encryption-key"
$adAppDisplayName = "it-iac-d-dsk-prn"
$keyVaultadAppSecretName = "$adAppDisplayName-password"

$secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultadAppSecretName

$aadClientID = (Get-AzureRmADApplication -DisplayNameStartWith $adAppDisplayName).ApplicationId
Write-Verbose "Client ID is $aadClientID"
$keyVault = Get-AzureRmKeyVault -ResourceGroupName $keyVaultResourceGroupName -VaultName $keyVaultName
$diskEncryptionKeyVaultUrl = $keyVault.VaultUri
Write-Verbose "diskEncryptionKeyVaultUrl is $diskEncryptionKeyVaultUrl"
$KeyVaultResourceId = $keyVault.ResourceId
Write-Verbose "KeyVaultResourceId is $KeyVaultResourceId"
$keyEncryptionKeyUrl = (Get-AzureKeyVaultKey -VaultName $keyVaultName -Name $keyEncryptionKeyName).Key.Kid
Write-Verbose "keyEncryptionKeyUrl is $keyEncryptionKeyUrl"

# Set-AzureRmVMDiskEncryptionExtension `
# -ResourceGroupName $resourceGroupName `
# -VMName $vmName -AadClientID $aadClientID `
# -AadClientSecret $secret.SecretValueText `
# -KeyEncryptionKeyUrl $keyEncryptionKeyUrl `
# -KeyEncryptionKeyVaultId $KeyVaultResourceId `
# -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl `
# -DiskEncryptionKeyVaultId $KeyVaultResourceId `
# -VolumeType All -skipVmBackup -Force `
# -SequenceVersion 7 `
# -Verbose