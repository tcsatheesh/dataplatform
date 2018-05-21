param (
    [string]$storageAccountResourceGroupName,
    [string]$storageAccountName,
    [string]$localFolder,
    [string]$containerName
)

function Set-ToBlobStore {
    param(
        [string]$localFolder,
        [string]$containerName
    )
    #Get the storage account key
    $storageAccountKey = (Get-AzureRmStorageAccountKey `
            -ResourceGroupName $storageAccountResourceGroupName `
            -Name $storageAccountName)[1].Value
    #Get the storage context
    $storageContext = New-AzureStorageContext `
        -StorageAccountName $storageAccountName `
        -StorageAccountKey $storageAccountKey
    $context = Get-AzureStorageContainer -Name $containerName -Context $storageContext -ErrorAction SilentlyContinue
    if ($context -eq $null) {
        #Create a new container in the storage account
        Write-Verbose "Container does not exist. Creating..."
        New-AzureStorageContainer -Name $containerName `
            -Context $storageContext -Permission Container
        Write-Verbose "Container created."
    }
    else {
        Write-Verbose "Container exists..."
    }
    #get storage end point to store the config files
    $storageEndPoint = New-AzureStorageContainerSASToken -Name $containerName `
        -Permission rwdl -Context $storageContext -FullUri
    Write-Verbose "Copying scripts..."
    #Copy aretfacts to the storage area
    & AzCopy /Source:$localFolder /Dest:$storageEndPoint /Y /s    
}

Set-ToBlobStore -localFolder $localFolder -containerName $containerName