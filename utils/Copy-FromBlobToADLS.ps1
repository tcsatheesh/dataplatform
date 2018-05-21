param (
    [string]$storageAccountResourceGroupName,
    [string]$storageAccountName,
    [string]$containerName,
    [string]$adlStoreName,
    [string]$adlsPath
)

$storageAccountKey = (Get-AzureRmStorageAccountKey `
-ResourceGroupName $storageAccountResourceGroupName `
-Name $storageAccountName)[1].Value

$source = "https://$storageAccountName.blob.core.windows.net/$containerName/"
$dest = "adl://$adlStoreName.azuredatalakestore.net/$adlsPath/"
& AdlCopy /Source $source /dest $dest /sourcekey $storageAccountKey