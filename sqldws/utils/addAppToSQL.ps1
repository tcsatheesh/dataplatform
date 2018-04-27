Param
(
    [Parameter(Mandatory = $True, HelpMessage = 'Specify the parameter file')]
    [String]$projectsParamterFile
)

function Get-SQLStr {
    $sqlInput = "
if not exists (select * from sys.symmetric_keys where name like '%DatabaseMasterKey%')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD ='{masterKey}' 

if not exists (SELECT * FROM sys.database_CREDENTIALs where name='{applicationPrincipalName}')
    CREATE DATABASE SCOPED CREDENTIAL [{applicationPrincipalName}]
    WITH (
        IDENTITY = '{servicePrincipalId}@https://login.microsoftonline.com/{tenantId}/oauth2/token',
        SECRET = '{clientSecret}'; 
    )

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
    WITH (
        IDENTITY = 'user',
        SECRET = '{storageAccountKey}';
    )

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
    if ($parameter.type -eq "reference") {
        if ($parameter.ref.subTypeFilter -eq $null) {
            $val = Get-ValueFromResource `
            -resourceType $parameter.ref.resourceType `
            -typeFilter $parameter.ref.typeFilter `
            -property $parameter.ref.name
            -subTypeFilter $parameter.ref.subTypeFilter        
        }
        else {
            $val = Get-ValueFromResource `
                -resourceType $parameter.ref.resourceType `
                -typeFilter $parameter.ref.typeFilter `
                -property $parameter.ref.name
        }
    }
    else if ($parameter.type -eq "value"){
        $val = $parameter.value
    }
    return $val
}

function Get-Secret {
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

function Set-Database {
    param (
        [object]$resource
    )
    $databaseName = $resource.name

    $keyVaultName = Get-Parameter -resource $resource -filterName "keyvault" 

    $masterKeyToken = "{masterKey}"
    $masterKeyName = Get-Parameter -resource $resource -filterName "masterkeyName"
    $masterKey = Get-Secret -keyVaultName $keyVaultName -secretName $masterKeyName

    $applicationPrincipalNameToken = "{applicationPrincipalName}"
    $applicationPrincipalName = Get-Parameter -resource $resource -filterName "applicationPrincipalName"
    
    $tenantIdToken = "{tenantId}"
    $tenantId = Get-Parameter -resource $resource -filterName "tenant"

    $servicePrincipalIdToken = "{servicePrincipalId}"
    $servicePrincipalId = Get-Parameter -resource $resource -filterName "servicePrincipalId"
 
    $clientSecretToken = "{clientSecret}"
    $secretName = Get-Parameter -resource $resource -filterName "applicationPrincipalSecretName"
    $clientSecret = Get-Secret -keyVaultName $keyVaultName -secretName $secretName
       
    $dataLakeStoreNameToken = "{dataLakeStoreName}"
    $dataLakeStoreName = Get-Parameter -resource $resource -filterName "dataLakeStoreName"
       
    $fileFormatNameToken = "{fileFormatName}"
    $fileFormatName = Get-Parameter -resource $resource -filterName "fileFormatName"

    $storageAccountNameToken = "{storageAccountName}"
    $storageAccountResourceGroupName = Get-Parameter -resource $resource -filterName "storageaccountresourcegroup"
    $storageAccountName = Get-Parameter -resource $resource -filterName "storageaccount"

    $storageAccountKeyToken = "{storageAccountKey}"
    $storageAccountKeys = Get-AzureRmStorageAccountKey -ResourceGroupName $storageAccountResourceGroupName -Name $storageAccountName
    $storageAccountKey = $storageAccountKeys[0].Value

    $containerNameToken = "{containerName}"
    $containerName = Get-Parameter -resource $resource -filterName "containername"
    
    $storageContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
    $context = Get-AzureStorageContainer -Name $containerName -Context $storageContext
    if ($context -eq $null) {
        #Create a new container in the storage account
        Write-Verbose "Container $containerName does not exist. Creating..."
        New-AzureStorageContainer -Name $containerName -Context $storageContext -Permission Off
        Write-Verbose "Container $containerName created."
    }
    else {
        Write-Verbose "Container $containerName exists..."
    }

        
    $sqlInput = $sqlInput -replace $masterKeyToken, $masterKey
    $sqlInput = $sqlInput -replace $applicationPrincipalNameToken, $applicationPrincipalName
    $sqlInput = $sqlInput -replace $tenantIdToken, $tenantId
    $sqlInput = $sqlInput -replace $servicePrincipalIdToken, $servicePrincipalId
    $sqlInput = $sqlInput -replace $clientSecretToken, $clientSecret
    $sqlInput = $sqlInput -replace $dataLakeStoreNameToken, $dataLakeStoreName
    $sqlInput = $sqlInput -replace $fileFormatNameToken, $fileFormatName
    $sqlInput = $sqlInput -replace $storageAccountKeyToken, $storageAccountKey
    $sqlInput = $sqlInput -replace $containerNameToken, $containerName
    $sqlInput = $sqlInput -replace $storageAccountNameToken, $storageAccountName

    $sqlUserCmdTmpFile = New-TemporaryFile
    Write-Verbose "Writing $sqlUserCmdTmpFile with details"

    $sqlInput | Out-File -filepath $sqlUserCmdTmpFile -Force

    notepad $sqlUserCmdTmpFile

    $sqlServerName = Get-Parameter -resource $resource -name "sqlServerName"
    $sqlServerAdminLogin = Get-Parameter -resource $resource -name "sqladmin"
    $secretName = Get-Parameter -resource $resource -name "sqladminpassword"
    $sqlAdminPassword = Get-Secret -VaultName $keyVaultName -secretName $secretName
    $sqlServerInstance = "{0}.database.windows.net" -f $sqlServerName

    Write-Verbose "SQL Server Instance : $sqlServerInstance"
    #Install the online sign in assistant from here http://go.microsoft.com/fwlink/?LinkId=234947
    #Install ODBC 13.1 from here https://www.microsoft.com/en-us/download/details.aspx?id=53339.    
    #Install SQLCMD 13.1 minimum required for this to run. Look here https://www.microsoft.com/en-us/download/details.aspx?id=53591. 
    # $sqlcmd = 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\SQLCMD.EXE'
    # & $sqlcmd -i $sqlUserCmdTmpFile -S $sqlServerInstance -d $databaseName -I -U $sqlServerAdminLogin -P $sqlAdminPassword
    #Invoke-Sqlcmd -InputFile $sqlUserCmdTmpFile -ServerInstance $sqlServerInstance -Database $databaseName -Username $sqlServerAdminLogin -Password $sqlAdminPassword
}









