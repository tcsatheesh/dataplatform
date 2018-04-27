param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

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

function Set-Resource {
    param (
        [object]$resource
    )
    $databaseName = $resource.name

    $keyVaultName = Get-ParameterValue -resource $resource -filterName "keyvault" 

    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $resourceTypeFolder = "$projectFolder\$($resource.resourceType)"
    $sqlcmdFile = "$resourceTypeFolder\$($resource.name).sql"
    $sqlInput = Get-Content -Path $sqlcmdFile -Raw
    Write-Verbose "Reading $sqlcmdFile with details"

    $masterKeyToken = "{masterKey}"
    $masterKeyName = Get-ParameterValue -resource $resource -filterName "masterkeyName"
    $masterKey = Get-SecretValue -keyVaultName $keyVaultName -secretName $masterKeyName
 
    $clientSecretToken = "{clientSecret}"
    $secretName = Get-ParameterValue -resource $resource -filterName "applicationPrincipalSecretName"
    $clientSecret = Get-SecretValue -keyVaultName $keyVaultName -secretName $secretName
       
    $storageAccountKeyToken = "{storageAccountKey}"
    $storageAccountResourceGroupName = Get-ParameterValue -resource $resource -filterName "storageaccountresourcegroup"
    $storageAccountName = Get-ParameterValue -resource $resource -filterName "storageaccount"
    $storageAccountKeys = Get-AzureRmStorageAccountKey -ResourceGroupName $storageAccountResourceGroupName -Name $storageAccountName
    $storageAccountKey = $storageAccountKeys[0].Value

    $sqlInput = $sqlInput -replace $masterKeyToken, $masterKey
    $sqlInput = $sqlInput -replace $clientSecretToken, $clientSecret
    $sqlInput = $sqlInput -replace $storageAccountKeyToken, $storageAccountKey

    $sqlServerName = Get-ParameterValue -resource $resource -filterName "sqlServerName"
    $sqlServerAdminLogin = Get-ParameterValue -resource $resource -filterName "sqladmin"
    $secretName = Get-ParameterValue -resource $resource -filterName "sqladminpassword"
    $sqlAdminPassword = Get-SecretValue -keyVaultName $keyVaultName -secretName $secretName
    $sqlServerInstance = "{0}.database.windows.net" -f $sqlServerName

    Write-Verbose "SQL Server Instance : $sqlServerInstance"
    #Install the online sign in assistant from here http://go.microsoft.com/fwlink/?LinkId=234947
    #Install ODBC 13.1 from here https://www.microsoft.com/en-us/download/details.aspx?id=53339.    
    #Install SQLCMD 13.1 minimum required for this to run. Look here https://www.microsoft.com/en-us/download/details.aspx?id=53591. 
    # $sqlcmd = 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\SQLCMD.EXE'
    # & $sqlcmd -i $sqlUserCmdTmpFile -S $sqlServerInstance -d $databaseName -I -U $sqlServerAdminLogin -P $sqlAdminPassword
    #Invoke-Sqlcmd -InputFile $sqlUserCmdTmpFile -ServerInstance $sqlServerInstance `
        # -Database $databaseName -Username $sqlServerAdminLogin -Password $sqlAdminPassword

    Invoke-Sqlcmd -Query $sqlInput -ServerInstance $sqlServerInstance `
        -Database $databaseName -Username $sqlServerAdminLogin -Password $sqlAdminPassword
}



function Set-Resources {
    foreach ($resource in $parameters.parameters.resources.value) {
        Write-Verbose "Processing resource $($resource.name)"
        Set-Resource -resource $resource
    }
}

$resourceType = (Get-Item -path $PSScriptRoot).Parent.Name

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$parameterFileName = "$resourceType.parameters.json"

& "$commonPSFolder\Invoke-SetProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType $resourceType `
    -parameterFileName $parameterFileName `
    -procToRun {Set-Resources}
