param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,

    [Parameter(Mandatory = $False, HelpMessage = 'The master credential.')]
    [PSCredential]$masterCredential
)
function Set-AppRole {
    param (
        [string]$resourceName,
        [string]$roleName,
        [string]$objectId
    )
    $app = Get-AzureADServicePrincipal -SearchString $resourceName
    $role = $app.AppRoles | Where-Object {$_.Value -eq $roleName}
    if ($role -eq $null) {
        throw "Role $roleName not found in app $resourceName" 
    }
    else {
        Write-Verbose "Role $roleName exists in resource $resourceName"
    }
    function AssignmentDoesNotExist {
        param(
            [string]$objectId,
            [string]$id
        )
        $assignments = Get-AzureADServiceAppRoleAssignedTo -ObjectId $objectId
        foreach ($assignment in $assignments) {
            if ($assignment.Id -eq $id) {
                Write-Verbose "Assignment $($assignment.Id) exists in objectId $objectId"
                return $false
            }
        }
        Write-Verbose "Assignment $($assignment.Id) does not exist in objectId $objectId"
        return $true 
    }

    if (AssignmentDoesNotExist -objectId $objectId -id $role.Id ) {
        $NewAssignmentParams = @{
            'Id'          = $role.Id;
            'ObjectId'    = $objectId;
            'PrincipalId' = $objectId;
            'ResourceId'  = $app.ObjectId;
        }
        Write-Verbose "Id $($role.Id) ObjectId $objectId ResourceId $($app.ObjectId)"
        $role = New-AzureADServiceAppRoleAssignment @NewAssignmentParams 
        Write-Verbose "Assignment $roleName created"
    }
    else {
        Write-Verbose "Assignment $roleName exists"
    }
}

function Set-AppRoles {
    param (
        [string]$resourceName,
        [object]$scopes,
        [string]$objectId
    )
    foreach ($scope in $scopes) {
        Set-AppRole -resourceName $resourceName -roleName $scope -objectId $objectId
    }
}

function Get-OAuth2Permissions {
    param (
        [string]$accessToken,
        [string]$clientId
    )

    $uri = "https://graph.windows.net/myorganization/oauth2PermissionGrants?api-version=1.6&`$filter=clientId+eq+'{0}'" -f $clientId
    $params = @{    
        ContentType = 'application/json'
        Headers     = @{
            'Authorization' = "Bearer $accessToken"
        }
        Method      = 'Get'    
        URI         = $uri
    }
    Write-Verbose "Getting the OAuth2Permissions"
    $authZResponse = Invoke-RestMethod @params
    return $authZResponse
}

function Set-OAuth2Permission {
    param (
        [string]$accessToken,
        [string]$clientId,
        [string]$resourceId,
        [string]$scope
    )   
    $grantDefinition = "{
        'odata.type': 'Microsoft.DirectoryServices.OAuth2PermissionGrant',
        'clientId': '',
        'consentType': 'AllPrincipals',
        'principalId': null,
        'resourceId': '',
        'scope': '',
        'startTime': '0001-01-01T00:00:00',
        'expiryTime': '9000-01-01T00:00:00'
    }"
    $grantDefinition.clientId = $clientId
    $grantDefinition.resourceId = $resourceId
    $grantDefinition.scope = $scope

    $body = $grantDefinition | ConvertTo-JSON -Depth 10

    Write-Verbose "Body is $body"

    $uri = "https://graph.windows.net/myorganization/oauth2PermissionGrants?api-version=1.6"
    $params = @{    
        ContentType = 'application/json'
        Headers     = @{
            'Authorization' = "Bearer $accessToken"
        }
        body        = $body
        Method      = 'Post'    
        URI         = $uri
    }
    Write-Verbose "Grant OAuth2Permission clientId $clientId resourceId $resourceId scope $scope"
    $authZResponse = Invoke-RestMethod @params    
}

function Set-OAuth2Permissions {
    param (
        [string]$accessToken,
        [string]$resourceId,
        [string]$clientId,
        [object]$scopes
    )

    $oauth2Perms = Get-OAuth2Permissions -accessToken $accessToken -clientId $clientId
    $oauth2Perm = $oauth2Perms.value | Where-Object {$_.resourceId -eq $resourceId}
    if ($oauth2Perm -eq $null) {
        Write-Verbose "Permissions for resource $resourceName does not exist"
        Set-OAuth2Permission -accessToken $accessToken -clientId $clientId $resourceId -scope $scopes
    }
    else {
        Write-Verbose "Permissions already exists for this resource $resourceName in service principal $clientId"
        foreach ($scope in $scopes.Split("")) {
            $isPresent = $false
            foreach ($perm in $oauth2Perm.scope.Split(" ")) {
                if ($perm -eq $scope) {
                    $isPresent = $True
                }
            }
            if ($isPresent) {
                Write-Verbose "Scope $scope already exists."
            }
            else {
                Write-Verbose "Scope $scope does not exist. Adding..."
            }
        }
    }
}

function Set-ResourcePermissions {
    param (
        [string]$accessToken,
        [string]$resourceName,
        [string]$scopes,
        [string]$clientId
    )
    $resource = Get-AzureADServicePrincipal -SearchString $resourceName
    $resource = $resource | Where-Object {$_.DisplayName -eq $resourceName}
    if ($resource -eq $null) {
        throw "The resource $resourceName does not exist"
    }
    $resourceId = $resource.ObjectId

    Set-OAuth2Permissions -accessToken $accessToken -resourceId $resourceId -clientId $clientId -scopes $scopes
}


function Get-AccessToken {
    param (
        [string]$tenantId,
        [PSCredential]$clientCredential
    )

    function Get-AccessTokenWeb {
        param (
            [string]$tenantId,
            [string]$clientId,
            [string]$clientSecret
        )
        $body = "grant_type=client_credentials&resource=https%3A%2F%2Fgraph.windows.net%2F&client_id={0}&client_secret={1}" -f $clientId, $clientSecret
        $vstsURL = "https://login.microsoftonline.com/{0}/oauth2/token" -f $tenantId
        $params = @{    
            ContentType = 'application/x-www-form-urlencoded'
            body        = $body
            Method      = 'Post'    
            URI         = $vstsURL
        }
        Write-Verbose "Getting the access token"
        $authZResponse = Invoke-RestMethod @params
        return $authZResponse.access_token
    }

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientCredential.Password)
    $clientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    return Get-AccessTokenWeb -tenantId $tenantId -clientId $clientCredential.UserName -clientSecret $clientSecret
}

function Set-Resource {
    param (
        [object]$resource
    )
    Write-Verbose "Processing application $($resource.name)"
    
    $objectIdObj = $resource.parameters | Where-Object {$_.name -eq "objectId"}
    if ($objectIdObj.type -eq "value") {
        $objectId = $objectIdObj.value
    }
    else {
        $objectId = Get-ValueFromResource -resourceType $objectIdObj.ref.resourceType -property $objectIdObj.ref.property -typeFilter $objectIdObj.ref.typeFilter -subtypeFilter $objectIdObj.ref.subtypeFilter
    }

    $winAADResource = $resource.parameters | Where-Object { $_.type -eq "appRole"}
    if ($winAADResource -ne $null) {
        Set-AppRoles -objectId $objectId -resourceName $winAADResource.name -scopes $winAADResource.value
    }

    $OAuth2Permissions = $resource.parameters | Where-Object { $_.name -eq "OAuth2Permissions"}
    if ($OAuth2Permissions -ne $null) {
        $ref = ($resource.parameters | Where-Object { $_.name -eq "tenantId"}).ref
        $tenantId = Get-ValueFromResource -resourceType $ref.resourceType -property $ref.property -typeFilter $ref.typeFilter
        Write-Verbose "Tenant Id is $tenantId"

        $ref = ($resource.parameters | Where-Object { $_.name -eq "masterClientId"}).ref
        $masterClientId = Get-ValueFromResource -resourceType $ref.resourceType -property $ref.property -typeFilter $ref.typeFilter
        Write-Verbose "Master Client Id is $masterClientId"
        
        $ref = ($resource.parameters | Where-Object { $_.name -eq "masterClientIdPassword"}).ref
        $keyVaultName = = Get-ValueFromResource -resourceType $ref.resourceType -property "name" -typeFilter $ref.typeFilter
        $masterClientIdPassword = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $ref.secretName

        $masterCredential = New-Object System.Management.Automation.PSCredential ($masterClientId, $masterClientIdPassword.SecretValue)
        $accessToken = Get-AccessToken -tenantId $tenantId -clientCredential $masterCredential

        Set-ResourcePermissions -accessToken $accessToken -resourceName $OAuth2Permissions.name -scopes $OAuth2Permissions.value -clientId $objectId 
    }
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName

