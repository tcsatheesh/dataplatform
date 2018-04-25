$location = "North Europe"
$publisher = ""
$extensionType = "AzureDiskEncryptionForLinux"
$extensionType = "CustomScriptForLinux"

Get-AzureRmVmImagePublisher -Location $location | `
Get-AzureRmVMExtensionImageType | `
Get-AzureRmVMExtensionImage | Where-Object {$_.Type -eq $extensionType}

#| Select-Object Type, Version 