param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Get-Secret {
    param (
        [object]$resource,
        [string]$name
    )
    $parameter = $resource.parameters | Where-Object {$_.name -eq $name}
    $keyVaultName = Get-ValueFromResource `
        -resourceType $parameter.ref.resourceType `
        -typeFilter $parameter.ref.typeFilter `
        -property "name"
    $secretName = $parameter.ref.secretName
    $secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretName
    return $secret
}

function AddUsertoSql
{
    param
    (
        [string]$sqlServerUserLogin,
        [string]$sqlServerUserPassword,
        [string]$sqlServerAdminLogin,
        [string]$sqlServerAdminPassword,
        [string]$sqlServerName,
        [string]$sqlDatabaseName
    )
    $sqlLoginStr = "
        IF NOT EXISTS (SELECT * FROM sys.sql_logins WHERE name = '{0}')
        BEGIN
            CREATE LOGIN [{0}] WITH password='{1}'
        END
        "    
    $sqlLoginCmdStr = $sqlLoginStr -f $sqlServerUserLogin, $sqlServerUserPassword
    $sqlLoginCmdTmpFile = New-TemporaryFile
    $sqlLoginCmdStr > $sqlLoginCmdTmpFile
    
    $sqlUserStr="
        IF NOT EXISTS (SELECT * FROM sys.sysusers WHERE name='{0}')
        BEGIN
            CREATE USER [{0}] FOR LOGIN [{0}] WITH DEFAULT_SCHEMA=[dbo]
        END
        "
    $sqlUserCmdStr = $sqlUserStr -f $sqlServerUserLogin
    $sqlUserCmdTmpFile = New-TemporaryFile
    $sqlUserCmdStr > $sqlUserCmdTmpFile


    $sqlServerInstance = "{0}.database.windows.net" -f $sqlServerName
    Invoke-Sqlcmd -InputFile $sqlLoginCmdTmpFile -ServerInstance $sqlServerInstance -Database "master" -Username $sqlServerAdminLogin -Password $sqlServerAdminPassword
    Write-Verbose "New login $sqlServerUserLogin created in sql server $sqlServerInstance"
    
    Invoke-Sqlcmd -InputFile $sqlUserCmdTmpFile -ServerInstance $sqlServerInstance -Database $sqlDatabaseName -Username $sqlServerAdminLogin -Password $sqlServerAdminPassword
    Write-Verbose "New user $sqlServerUserLogin added to database $sqlDatabaseName"
}

function Set-Resource {
    param (
        [object]$resource
    )
    $sqlUserLoginName = $resource.name
    $parameter = $resource.parameters | Where-Object {$_.name -eq "sqlServerName"}
    $sqlServerName = $parameter.value
    $parameter = $resource.parameters | Where-Object {$_.name -eq "databaseName"}
    $databaseName = Get-ValueFromResource `
        -resourceType $parameter.ref.resourceType `
        -typeFilter $parameter.ref.typeFilter `
        -property $parameter.ref.property
    $sqlUserLoginSecret = Get-Secret -resource $resource -name "password"
    $parameter = $resource.parameters | Where-Object {$_.name -eq "sqladmin"}
    $sqlAdminLoginName = $parameter.value
    $sqlAdminLoginSecret = Get-Secret -resource $resource -name "sqladmin-password"
    AddUsertoSql `
        -sqlServerUserLogin $sqlUserLoginName `
        -sqlServerUserPassword $sqlUserLoginSecret.SecretValueText `
        -sqlServerAdminLogin $sqlAdminLoginName `
        -sqlServerAdminPassword $sqlAdminLoginSecret.SecretValueText `
        -sqlServerName $sqlServerName `
        -sqlDatabaseName $databaseName
}

function Set-Resources {
    foreach ($resource in $parameters.parameters.resources.value) {
        $enabled = $resource.enabled
        if ($enabled -ne $null) {
            $enabled = [System.Convert]::ToBoolean($resource.enabled)   
        }else{
            $enabled = $true
        }
        if ( $enabled ) {
            Write-Verbose "Processing resource $($resource.name)"
            Set-Resource -resource $resource
        }else {
            Write-Verbose "Skipping resource: $($resource.name)"
        }
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"

& "$commonPSFolder\Invoke-SetProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name `
    -parameterFileName $parameterFileName `
    -procToRun {Set-Resources}
