param (
    [Parameter(Mandatory = $True, HelpMessage = 'The storage account resource group name.')]
    [string]$storageAccountResourceGroupName,
    [Parameter(Mandatory = $True, HelpMessage = 'The storage account name.')]
    [string]$storageAccountName,
    [Parameter(Mandatory = $False, HelpMessage = 'The storage account container name. Default is source.')]
    [string]$containerName = "source",
    [Parameter(Mandatory = $False, HelpMessage = 'The source folder relative to the script file. Default is data1.')]
    $sourcedir = "products",
    [Parameter(Mandatory = $False, HelpMessage = 'The number of hours to add to the timestamp. Default is -2.')]
    $addHours = -2
)

function Zip-It {
    $source = "{0}\{1}.txt" -f $PSScriptRoot, $sourcedir
    $datetimestamp = (Get-Date).AddHours($addHours).ToString("yyyyMMddHHmm")
    $destinationFileName = "{0}_{1}.csv" -f $sourcedir, $datetimestamp
    $destination = "{0}\{1}" -f $PSScriptRoot, $destinationFileName
    Write-Verbose "Destination File Path: $destination"
    if (Test-path $destination) {
        Remove-item $destination -Force
    } 
    Copy-Item -Path $source -Destination $destination
    Write-Verbose "Destination File Name is $destinationFileName"
    return $destinationFileName
}

$sourceFolder = $PSScriptRoot
$fileName = Zip-It
Write-Verbose "Pattern is $fileName"
$destinationFolder = "https://{0}.blob.core.windows.net/{1}" -f $storageAccountName, $containerName

$stg = Get-AzureRmStorageAccountKey -ResourceGroupName $storageAccountResourceGroupName -Name $storageAccountName
$destinationKey = $stg[0].Value

$AzCopy = "C:\program files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
& $AzCopy /Source:$sourceFolder /Dest:$destinationFolder /DestKey:$destinationKey /Pattern:$fileName