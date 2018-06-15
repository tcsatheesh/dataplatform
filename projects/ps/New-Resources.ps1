param
(    
    [Parameter(Mandatory = $True, HelpMessage = 'The name of the department.')]
    [String]$department,
    
    [Parameter(Mandatory = $True, HelpMessage = 'The name of the project.')]
    [String]$projectName,
    
    [Parameter(Mandatory = $True, HelpMessage = 'The environment for this project.')]
    [String]$environment,

    [Parameter(Mandatory = $True, HelpMessage = 'The environment for this project.')]
    [String]$tenant,

    [Parameter(Mandatory = $True, HelpMessage = 'The vsts account name.')]
    [String]$vstsaccountname,

    [Parameter(Mandatory = $True, HelpMessage = 'The vsts account branch.')]
    [String]$branch,

    [Parameter(Mandatory = $False, HelpMessage = 'Should we create AD Groups in Azure AD.')]
    [bool]$createADGroups = $false,

    [Parameter(Mandatory = $False, HelpMessage = 'The project folder')]
    [string]$projectFolder = $null,

    [Parameter(Mandatory = $True, HelpMessage = 'The type of environment to deploy.')]
    [String]$envtype
)

function Get-SubscriptionDetails {
    $subscriptionId = $null
    $tenantId = $null
    
    try {
        $subscription = Get-AzureRmSubscription    
    }
    catch {
        Write-Output "Login to Azure"
        $subscription = Login-AzureRmAccount -ErrorAction SilentlyContinue
        if ($subscription -eq $null) {
            throw "You will need to Login to Azure to complete this script."
        }
        else {
            $subscription = Get-AzureRmSubscription
        }    
    }
    
    if ($subscription.Count -eq 0) {
        throw "You will need an Azure Subscription to run this script."
    }
    if ($subscription.Count -eq 1) {
        $subscriptionName = $subscription.Name
        $subscriptionId = $subscription.SubscriptionId
        $tenantId = $subscription.TenantId
    }
    if ($subscription.Count -gt 1) {
        $subCount = $subscription.Count
        Write-Host "Select the Azure Subscription to use"
        for ($index = 1; $index -le $subCount ; $index++) {
            $name = $subscription[$index - 1].Name
            $subscriptionId = $subscription[$index - 1].SubscriptionId
            Write-Host "$index : $name - $subscriptionId"
        }
        do {
            $selectedItem = Read-Host "Select Azure Subscription" 
            if ($selectedItem -le $subCount -and $selectedItem -gt 0) {
                $subscriptionName = $subscription[$selectedItem - 1].Name
                $subscriptionId = $subscription[$selectedItem - 1].SubscriptionId
                $tenantId = $subscription[$selectedItem - 1].TenantId
                Write-Verbose "Subscription selected is $subscriptionId"
            }
            else {
                Write-Warning "Selection must be from 1 to $subCount"            
            }
        }while ($selectedItem -gt $subCount -or $selectedItem -lt 0)
    }
    $sub = Select-AzureRmSubscription -SubscriptionId $subscriptionId
    $tenantDomainName = $tenant

    $props = @{
        subscriptionName = $subscriptionName
        subscriptionId   = $subscriptionId
        tenantId         = $tenantId
        tenantName       = $tenantDomainName
    }
    return $props
}

function Get-OutputFile {
    $parameterFileName = "projects.parameters.json"
    $projectFolderName = "{0}-{1}-{2}" -f $department, $projectName, $environment
    $selectedProjectFolder = $projectFolder
    if ([string]::IsNullOrEmpty($selectedProjectFolder)) {    
        $selectedProjectFolder = "$PSScriptRoot\..\..\projects\$projectFolderName"
    }
    $projectFolder = New-Item -Path $selectedProjectFolder -ItemType Directory -Force
    $projectParameterFullPath = "$selectedProjectFolder\$parameterFileName"
    Write-Verbose "Project Parameter Full Path: $projectParameterFullPath"
    return $projectParameterFullPath
}

function Update-OutputFile {
    param (
        [object]$parameters
    )
    $projectsParameterFile = Get-OutputFile
    $parameters | ConvertTo-JSON -Depth 10 | Out-File -filepath $projectsParameterFile -Force -Encoding utf8
    Write-Verbose "Project parameter file created at: $projectsParameterFile"
    return $projectParameterFullPath    
}

function New-Resources2 {
    param (
        [object]$parameters
    )
    $resources = $parameters.parameters.resources.value

    $resource = $resources | Where-Object {$_.type -eq "department"}
    $resource.name = $department

    $resource = $resources | Where-Object {$_.type -eq "projectName"}
    $resource.name = $projectName

    $resource = $resources | Where-Object {$_.type -eq "environment"}
    $resource.name = $environment

    $resource = $resources | Where-Object {$_.type -eq "createADGroups"}
    $resource.status = $createADGroups

    $subdetails = Get-SubscriptionDetails 
    $resource = $resources | Where-Object {$_.type -eq "tenant"}
    $resource.name = $tenant
    $resource.id = $subdetails.tenantId

    $resource = $resources | Where-Object {$_.type -eq "subscription"}
    $resource.name = $subdetails.subscriptionName
    $resource.id = $subdetails.subscriptionId

    $resource = $resources | Where-Object {$_.type -eq "vstsaccount"}
    Write-Verbose $resource
    $resource.name = $vstsaccountname
    $resource.branch = $branch

    $newarray = @()
    $resources | ForEach-Object {
        $resource = $_;
        if ($resource.type -eq "department" -or `
                $resource.type -eq "projectName" -or `
                $resource.type -eq "environment" -or `
                $resource.type -eq "createADGroups" -or `
                $resource.type -eq "tenant" -or `
                $resource.type -eq "subscription" -or `
                $resource.type -eq "vstsaccount" -or `
                $resource.type -eq $envtype
        ) {
            $newarray += $resource
        }
    }
    $props = @{
        type = "envtype"
        value = $envtype
    }
    $newarray += $props

    $parameters.parameters.resources.value = $newarray
}

$parameters = Get-Content -Path (Get-Item -Path "$PSScriptRoot\..\templates\projects.parameters.json").FullName -Raw | ConvertFrom-JSON
New-Resources2 -parameters $parameters
Update-OutputFile -parameters $parameters