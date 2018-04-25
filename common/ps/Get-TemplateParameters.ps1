param(
    [Parameter(Mandatory = $True, HelpMessage = 'The name of the parameter file.')]
    [string]$resourceType,

    [Parameter(Mandatory = $True, HelpMessage = 'The name of the parameter file.')]
    [string]$parameterFileName
)
$templateParametersFullPath = "$PSScriptRoot\..\..\$resourceType\templates\$parameterFileName"
$templateParametersFullPath = (Get-Item -Path $templateParametersFullPath).FullName
Write-Verbose "Parameters Template Full Path: $templateParametersFullPath"
$parameters = Get-Content -Path $templateParametersFullPath -Raw | ConvertFrom-JSON
return $parameters
