param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,
    
    [Parameter(Mandatory = $True, HelpMessage = 'The type of resource.')]
    [String]$resourceType
)

function Copy-TemplateFile {
    param(
        [string]$resourceType,
        [string]$templateFileName
    )
    $sourcePath = (Get-Item -Path "$PSScriptRoot\..\..\$resourceType\templates\$templateFileName").FullName
    Write-Verbose "Source Path is $sourcePath"
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $destinationPath = "$projectFolder\$resourceType"
    $destinationPath = New-Item -Path $destinationPath -ItemType Directory -Force
    $destinationPath = "$destinationPath\$templateFileName"
    Write-Verbose "Destination Path is $destinationPath"
    Copy-Item -Path $sourcePath -Destination $destinationPath -Force
}

function Get-KeyVaultId {
    param (
        [object]$resourceType,
        [string]$typeFilter,
        [string]$secretName
    )
    $resourceGroupName = Get-ValueFromResource `
        -resourceType "resourcegroups" `
        -typeFilter "app" `
        -property "name"
    $keyVaultName = Get-ValueFromResource `
        -resourceType $resourceType `
        -typeFilter $typeFilter `
        -property "name"

    Write-Verbose "Resource group name is $resourceGroupName"
    $keyVault = Get-AzureRmKeyVault -ResourceGroupName $resourceGroupName -Name $keyVaultName 
    if ($keyVault -eq $null) {
        throw "keyvault $keyVaultName not found in resource group $resourceGroupName for resource type $resourceType and typefilter $typeFilter and secretname $secretName "
    }
    return $keyVault.ResourceId
}

function Get-BlobContainerUri {
    param (
        [object]$blobRef,
        [string]$containername
    )
    $storageAccountName = Get-ValueFromResource -resourceType $blobRef.resourceType `
        -property $blobRef.property -typeFilter $blobRef.typeFilter
    $storageAccount = Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $storageAccountName}
    $resourceGroupName = $storageAccount.ResourceGroupName
    $storageKey = Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName
    $starttime = Get-Date    
    $endtime = $starttime.AddYears(4) 

    $storageAccountContext = New-AzureStorageContext `
        -StorageAccountName $storageAccountName `
        -StorageAccountKey $storageKey[0].Value
    
    $container = Get-AzureStorageContainer `
        -Name $containerName -Context $storageAccountContext -ErrorAction SilentlyContinue
    if ($container -eq $null) {
        Write-Verbose "Container $containerName does not exist creating..."
        $container = New-AzureStorageContainer -Name $containerName -Context $storageAccountContext
    }
    else {
        Write-Verbose "Container $containerName already exists"
    }
    
    $containerSASURI = New-AzureStorageContainerSASToken -Name $containerName `
        -Permission rwdl -FullUri -Context $storageAccountContext `
        -StartTime $starttime -ExpiryTime $endtime
    return $containerSASURI
}

function Get-IotHubProperty {
    param (
        [object]$iothubRef,
        [string]$type
    )
    $iothubName = Get-ValueFromResource -resourceType $iothubRef.resourceType `
        -property $iothubRef.property -typeFilter $iothubRef.typeFilter
    $iothub = Get-AzureRmIotHub | Where-Object {$_.Name -eq $iothubName}
    if ($type -eq "iotHubConnectionString") {
        $val = (Get-AzureRmIotHubConnectionString -ResourceGroupName $iothub.Resourcegroup -Name $iothub.Name -KeyName device).PrimaryConnectionString
    }elseif ($ype -eq "iotHubResourceId") {
        $val = $iothub.Id
    }elseif ($ype -eq "iotHubSharedAccessKey") {
        $keys = Get-AzureRmIotHubKey -ResourceGroupName $iotHubResourceGroupName -Name $iotHubName -KeyName $tsInsightsKeyName
        $val = $keys.PrimaryKey
    }
    return $val
}

function Get-Fqdn {
    param (
        [object]$ref
    )
    $publicIPAddressName = Get-ValueFromResource -resourceType $ref.resourceType `
        -property $ref.property -typeFilter $ref.typeFilter
    $pip = Get-AzureRmPublicIpAddress | Where-Object {$_.name -eq $publicIPAddressName}
    if ($pip -eq $null) {
        throw "Public IP Address $publicIPAddressName not found"
    }else {
        $val = $pip1.DnsSettings.Fqdn
    }
    return $val
}

function Get-KeyEncryptionKeyUrl {
    param (
        [string]$resourceType,
        [string]$typeFilter,
        [string]$keyName
    )
    $keyVaultName = Get-ValueFromResource `
    -resourceType $resourceType `
    -typeFilter $typeFilter `
    -property "name"
    
    $keyEncryptionKeyUrl = (Get-AzureKeyVaultKey -VaultName $keyVaultName -Name $keyName).Key.Kid
    return $keyEncryptionKeyUrl
}

function Set-AdditionalParameters {
    param (
        [object]$resource,
        [object]$resourceParameters
    )

    Write-Verbose "Resource Parameters $resourceParameters"
    $resourceName = $resourceParameters.parameters.resourcename.value
    foreach ($resourceparam in $resource.parameters ) {
        Write-Verbose "resourceparam is $resourceparam"        
        $parametertoedit = $resourceparam.name
        Write-Verbose "Parameter to edit $parametertoedit"
        $index = $resourceparam.index
        $resourceTypeToLoad = $resourceparam.ref.resourceType
        
        $ref = $resourceparam.ref
        $propertyToExtract = $resourceparam.ref.property
        $typeFilter = $resourceparam.ref.typeFilter
        $subtypeFilter = $resourceparam.ref.subtypeFilter
        $value = $resourceparam.value

        if ($resourceparam.type -eq "keyvault") {
            $secretName = Get-FormatedText -strFormat $resourceparam.ref.secretName
            Write-Verbose "Secret name is $secretName"
            $resourceparam.ref.secretName = $secretName
            $resourceParameters.parameters.$parametertoedit.reference.secretName = $secretName
            $val = Get-KeyVaultId -resourceType $resourceTypeToLoad -typeFilter $typeFilter -secretName $secretName
            $resourceParameters.parameters.$parametertoedit.reference.keyVault.id = $val
        }
        else { 
            if ($resourceparam.type -eq "reference") {
                $val = Get-ValueFromResource -resourceType $resourceTypeToLoad `
                -property $propertyToExtract -typeFilter $typeFilter `
                -subtypeFilter $subtypeFilter
            
            }elseif ($resourceparam.type -eq "kekurl") {
                $keyName = Get-FormatedText -strFormat $resourceparam.ref.keyName
                $val = Get-KeyEncryptionKeyUrl -resourceType $resourceTypeToLoad `
                -typeFilter $typeFilter `
                -keyName $keyName
            }
            elseif ($resourceparam.type -eq "ipaddress") {
                $commonPSFolder = "$PSScriptRoot\..\..\common\ps"                
                $val = Get-CurrentIPAddress
                $resourceparam.value = $val
            }
            elseif ($resourceparam.type -eq "value") {
                $val = $resourceparam.value
            }
            elseif ($resourceparam.type -eq "format") {
                $val = Get-FormatedText -strFormat $resourceparam.value
                $resourceparam.value = $val
            }
            elseif ($resourceparam.type -eq "container") {
                $val = Get-BlobContainerUri -blobRef $resourceparam.ref -containername $resourceName
            }
            elseif (($resourceparam.type -eq "iotHubConnectionString") -or
                    ($resourceparam.type -eq "iotHubResourceId") -or 
                    ($resourceparam.type -eq "iotHubSharedAccessKey")
                    ) {
                $val = Get-IotHubProperty -iothubRef $resourceparam.ref `
                    -type $resourceparam.type
            }
            elseif ($resourceparam.type -eq "subnet") {
                Write-Verbose "This is handled else where."
            }
            elseif ($resourceparam.type -eq "fqdn") {
                $val = Get-Fqdn -ref $resourceparam.ref
            }
            else {
                throw "you are missing the resource type $($resourceparam.type)"
            }
            $subparametertoedit = $resourceparam.subname
            Write-Verbose "resourceTypeToLoad $resourceTypeToLoad with projectyToExtract $propertyToExtract with typeFilter $typeFilter and subFilter $subFilter has value $val"
            if ($subparametertoedit -eq $null) {
                $resourceParameters.parameters.$parametertoedit.value = $val
            }
            else {
                $resourceParameters.parameters.$parametertoedit.value[$index].$subparametertoedit = $val
            }
        }
    }
}

function New-ParameterFile {
    param(
        [object]$resource
    )    
    $resourceParameters = Get-TemplateParameters `
        -resourceType $resource.ResourceType `
        -parameterFileName $resource.parameterFileName
    
    $resourceParameters.parameters.resourcename.value = $resource.name
    $resourceParameters.parameters.location.value = $resource.location

    Set-AdditionalParameters -resource $resource -resourceParameters $resourceParameters

    $resourceParameterFileName = "$($resource.type).parameters.json"
    Set-ParametersToFile -resourceType $resource.resourceType `
        -parameters $resourceParameters `
        -parameterFileName $resourceParameterFileName
    return $resourceParameterFileName   
}

function New-Resource {
    param(
        [object]$resource
    )
    $resource.Name = Get-FormatedText($resource.name)    
    $resource.parameterFileName = New-ParameterFile -resource $resource
    Copy-TemplateFile -resourceType $resource.resourceType -templateFileName $resource.templateFileName
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType $resourceType -parameterFileName "$resourceType.parameters.json"