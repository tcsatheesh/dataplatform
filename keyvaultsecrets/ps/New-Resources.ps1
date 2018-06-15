param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function New-Resource {
    param (
        [object]$resource
    )
    $parameters = $resource.parameters
    if ($resource.type -eq "storageconnectionstring") {
        $val = Get-ValueFromResourceRef -parameters $resource.parameters -type "storageAccountName"
        $val = $resource.name -f $val
    }
    elseif ($resource.type -eq "login") {
        $res = $resource.parameters | Where-Object {$_.name -eq "resourcename"}
        $resname = Get-FormatedText -strFormat $res.value
        $res.value = $resname
        $account = $resource.parameters | Where-Object {$_.name -eq "account"}            
        $val = $resource.name -f $resname, $account.value
    }
    elseif ($resource.type -eq "sqldbconnectionstring") { 
        $sqlServer = $resource.parameters | Where-Object {$_.name -eq "sqlServerName"}
        $sqlServerName = Get-FormatedText -strFormat $sqlServer.value
        $sqlServer.value = $sqlServerName
        $sqlDatabase = $resource.parameters | Where-Object {$_.name -eq "sqlDatabaseName"}
        $sqlDatabaseName = Get-FormatedText -strFormat $sqlDatabase.value
        $sqlDatabase.value = $sqlDatabaseName
        $account = $resource.parameters | Where-Object {$_.name -eq "account"}
        $val = $resource.name -f $sqlServerName, $account.value
    }
    elseif ($resource.type -eq "certificate") { 
        $val = $resource.name
    }
    else {
            throw "resource type $($resource.type) not defined"
    }
    $resource.name = $val
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
