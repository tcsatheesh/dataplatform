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

function Get-Resource {
    param (
        [object]$resource
    )
    $databaseName = $resource.name

    $keyVaultName = Get-ParameterValue -resource $resource -filterName "keyvault" 

    $sqlServerName = Get-ParameterValue -resource $resource -filterName "sqlServerName"
    $sqlServerAdminLogin = Get-ParameterValue -resource $resource -filterName "sqladmin"
    $secretName = Get-ParameterValue -resource $resource -filterName "sqladminpassword"
    $sqlAdminPassword = Get-SecretValue -keyVaultName $keyVaultName -secretName $secretName
    $sqlServerInstance = "{0}.database.windows.net" -f $sqlServerName

    Write-Verbose "SQL Server Instance : $sqlServerInstance"
    $sqlInputs = @()
    $sqlInputs += "select * from sys.symmetric_keys where name like '%DatabaseMasterKey%'"
    $sqlInputs += "SELECT * FROM sys.database_CREDENTIALs where name='it-iac-d-app-prn'"
    $sqlInputs += "select * from sys.external_data_sources where name='itiacdneadlsstore'"
    $sqlInputs += "select * from sys.external_file_formats where name='itiacdadl01_DELIMITEDTEXT'"
    $sqlInputs += "SELECT * FROM sys.database_CREDENTIALs where name='itiacdnestgacc'"
    $sqlInputs += "select * from sys.external_data_sources where name='itiacdnestgacc'"
    
    foreach ($sqlInput in $sqlInputs) {
        Invoke-Sqlcmd -Query $sqlInput -ServerInstance $sqlServerInstance `
            -Database $databaseName -Username $sqlServerAdminLogin -Password $sqlAdminPassword
    }
}

function Get-Resources {
    foreach ($resource in $parameters.parameters.resources.value) {
        Write-Verbose "Processing resource $($resource.name)"
        Get-Resource -resource $resource
    }
}

$resourceType = (Get-Item -path $PSScriptRoot).Parent.Name

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$parameterFileName = "$resourceType.parameters.json"

& "$commonPSFolder\Invoke-SetProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType $resourceType `
    -parameterFileName $parameterFileName `
    -procToRun {Get-Resources}
