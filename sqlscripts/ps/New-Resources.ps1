param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Get-SQLStr {
    $sqlInput = "
if not exists (select * from sys.symmetric_keys where name like '%DatabaseMasterKey%')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD ='{masterKey}' 

if not exists (SELECT * FROM sys.database_CREDENTIALs where name='{applicationPrincipalName}')
    CREATE DATABASE SCOPED CREDENTIAL [{applicationPrincipalName}]
    WITH
        IDENTITY = '{servicePrincipalId}@https://login.microsoftonline.com/{tenantId}/oauth2/token',
        SECRET = '{clientSecret}';
    

if not exists (select * from sys.external_data_sources where name='{dataLakeStoreName}')
    CREATE EXTERNAL DATA SOURCE [{dataLakeStoreName}] 
    WITH (
        TYPE = HADOOP, 
        LOCATION = N'adl://{dataLakeStoreName}.azuredatalakestore.net', 
        CREDENTIAL = [{applicationPrincipalName}]
    );

if not exists (select * from sys.external_file_formats where name='{fileFormatName}')
    CREATE EXTERNAL FILE FORMAT [{fileFormatName}] 
    WITH (
        FORMAT_TYPE = DELIMITEDTEXT, 
        FORMAT_OPTIONS (
            FIELD_TERMINATOR = N',', 
            STRING_DELIMITER = N'""', 
            DATE_FORMAT = N'yyyy-MM-dd HH:mm:ss.fff', 
            USE_TYPE_DEFAULT = False
        )
    );

if not exists (SELECT * FROM sys.database_CREDENTIALs where name='{storageAccountName}')
    CREATE DATABASE SCOPED CREDENTIAL [{storageAccountName}]
    WITH
        IDENTITY = 'user',
        SECRET = '{storageAccountKey}';

if not exists (select * from sys.external_data_sources where name='{storageAccountName}')
    CREATE EXTERNAL DATA SOURCE [{storageAccountName}]
    WITH (
        TYPE = HADOOP,
        LOCATION = 'wasbs://{containerName}@{storageAccountName}.blob.core.windows.net',
        CREDENTIAL = [{storageAccountName}]
    );
"
    return $sqlInput
}

function Get-ParameterValue {
    param (
        [object]$resource,
        [string]$filterName
    )
    $parameter = $resource.parameters | Where-Object {$_.name -eq $filterName}
    if ($parameter -eq $null) {
        throw "parameter cannot be null for filter $filterName"
    }
    else {
        Write-Verbose "parameter is $parameter"
    }
try {
    if ($parameter.type -eq "reference") {
        if (-not ([String]::IsNullorEmpty($parameter.ref.subtypeFilter))) {
            $val = Get-ValueFromResource `
            -resourceType $parameter.ref.resourceType `
            -typeFilter $parameter.ref.typeFilter `
            -property $parameter.ref.property `
            -subtypeFilter $parameter.ref.subtypeFilter        
        }
        else {
            $val = Get-ValueFromResource `
                -resourceType $parameter.ref.resourceType `
                -typeFilter $parameter.ref.typeFilter `
                -property $parameter.ref.property
        }
    }
    elseif ($parameter.type -eq "value") {
        $val = $parameter.value
    }
    elseif ($parameter.type -eq "format") {
        $val = Get-FormatedText -strFormat $parameter.value
        $parameter.value = $val
    }
    else {
        throw "type $($parameter.type) is not handled."
    }
}
    catch {
        Write-Verbose "error in $($parameter.name)"
        throw
    } 
    return $val
}

function Get-SecretValue {
    param (
        [string]$keyVaultName,
        [string]$secretName
    )
    $secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretName -ErrorAction SilentlyContinue
    if ($secret -eq $null) {
        throw "secret $secretName is missing in the keyvault add it."
    }else{
        Write-Verbose "secret $secretName exists in key vault"
    }
    return $secret.SecretValueText
}

function New-Resource {
    param (
        [object]$resource
    )
    $databaseName = Get-FormatedText -strFormat $resource.name
    $resource.name = $databaseName
    
    $keyVaultName = Get-ParameterValue -resource $resource -filterName "keyvault" 

    $masterKeyToken = "{masterKey}"
    $masterKeyName = Get-ParameterValue -resource $resource -filterName "masterkeyName"

    $applicationPrincipalNameToken = "{applicationPrincipalName}"
    $applicationPrincipalName = Get-ParameterValue -resource $resource -filterName "applicationPrincipalName"
    
    $tenantIdToken = "{tenantId}"
    $tenantId = Get-ParameterValue -resource $resource -filterName "tenant"

    $servicePrincipalIdToken = "{servicePrincipalId}"
    $servicePrincipalId = Get-ParameterValue -resource $resource -filterName "servicePrincipalId"
 
    $clientSecretToken = "{clientSecret}"
    $secretName = Get-ParameterValue -resource $resource -filterName "applicationPrincipalSecretName"
       
    $dataLakeStoreNameToken = "{dataLakeStoreName}"
    $dataLakeStoreName = Get-ParameterValue -resource $resource -filterName "dataLakeStoreName"
       
    $fileFormatNameToken = "{fileFormatName}"
    $fileFormatName = Get-ParameterValue -resource $resource -filterName "fileFormatName"

    $storageAccountNameToken = "{storageAccountName}"
    $storageAccountResourceGroupName = Get-ParameterValue -resource $resource -filterName "storageaccountresourcegroup"
    $storageAccountName = Get-ParameterValue -resource $resource -filterName "storageaccount"

    $storageAccountKeyToken = "{storageAccountKey}"
    $storageAccountKeys = Get-AzureRmStorageAccountKey -ResourceGroupName $storageAccountResourceGroupName -Name $storageAccountName
    $storageAccountKey = $storageAccountKeys[0].Value

    $containerNameToken = "{containerName}"
    $containerName = Get-ParameterValue -resource $resource -filterName "containername"
    
    $storageContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
    $context = Get-AzureStorageContainer -Name $containerName -Context $storageContext -ErrorAction SilentlyContinue
    if ($context -eq $null) {
        #Create a new container in the storage account
        Write-Verbose "Container $containerName does not exist. Creating..."
        New-AzureStorageContainer -Name $containerName -Context $storageContext -Permission Off
        Write-Verbose "Container $containerName created."
    }
    else {
        Write-Verbose "Container $containerName exists..."
    }

    $sqlInput = Get-SQLStr        
    $sqlInput = $sqlInput -replace $applicationPrincipalNameToken, $applicationPrincipalName
    $sqlInput = $sqlInput -replace $tenantIdToken, $tenantId
    $sqlInput = $sqlInput -replace $servicePrincipalIdToken, $servicePrincipalId
    $sqlInput = $sqlInput -replace $dataLakeStoreNameToken, $dataLakeStoreName
    $sqlInput = $sqlInput -replace $fileFormatNameToken, $fileFormatName
    $sqlInput = $sqlInput -replace $containerNameToken, $containerName
    $sqlInput = $sqlInput -replace $storageAccountNameToken, $storageAccountName

    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $resourceTypeFolder = "$projectFolder\$($resource.resourceType)"
    $null = New-Item -Path $resourceTypeFolder -ItemType Directory -Force
    $sqlcmdFile = "$resourceTypeFolder\$($resource.name).sql"
    Write-Verbose "Writing $sqlcmdFile with details"

    $sqlInput | Out-File -filepath $sqlcmdFile -Force

    $sqlServerName = Get-ParameterValue -resource $resource -filterName "sqlServerName"
    $sqlServerAdminLogin = Get-ParameterValue -resource $resource -filterName "sqladmin"
    $secretName = Get-ParameterValue -resource $resource -filterName "sqladminpassword"
    $sqlServerInstance = "{0}.database.windows.net" -f $sqlServerName

    Write-Verbose "SQL Server Instance : $sqlServerInstance"
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
