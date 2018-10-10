param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-Application {
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

function Remove-Resource {
    param (
        [object]$resource
    )
    Remove-Application -applicationName $resource.application.name
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-RemoveProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName