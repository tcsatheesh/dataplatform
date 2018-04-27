param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-Resource {
    param (
        [string]$applicationName
    )
        
    $servicePrincipal = Get-AzureRmADServicePrincipal -SearchString $applicationName  -ErrorAction SilentlyContinue
    if ($servicePrincipal -ne $null) {
        Write-Verbose "Removing Azure AD Service Principal $applicationName"
        $servicePrincipal = Remove-AzureRmADServicePrincipal -ObjectId $servicePrincipal.Id -Force
        Write-Verbose "Removed Azure AD Service Principal $applicationName"
    }
    else {
        Write-Verbose "Azure AD Service Principal $applicationName does not exist"
    }

    $application = Get-AzureRmADApplication -DisplayNameStartWith $applicationName -ErrorAction SilentlyContinue
    if ($application -ne $null) {
        Write-Verbose "Removing Azure AD Application $applicationName"
        $application = Remove-AzureRmADApplication -ObjectId $application.ObjectId -Force
        Write-Verbose "Removed Azure AD Application $applicationName"
    }
    else {
        Write-Verbose "Azure AD Application does not exist $applicationName"
    }
}

function Remove-Resources {
    $resources = $parameters.parameters.resources.value | Where-Object {$_.type -eq "principal"} 
    foreach ($resource in $resources) {
        $enabled = $resource.enabled
        if ($enabled -ne $null) {            
            $enabled = [System.Convert]::ToBoolean($resource.enabled)   
        }else{
            $enabled = $true
        }
        if ( $enabled ) {
            Write-Verbose "Removing resource: $($resource.name)"
            Remove-Resource -applicationName $resource.application.name
        }else {
            Write-Verbose "Skipping removing resource: $($resource.name)"
        }
        
    }
}

$parameterFileName = "principals.parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-RemoveProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Remove-Resources}