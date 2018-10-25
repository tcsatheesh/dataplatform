param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Set-Assignment {
    param (
        [string]$name,
        [object]$assignments
    )
    
    $definition = Get-AzureRmPolicySetDefinition -Name $name

    $subscriptionId = Get-SubscriptionId
    $scope = "/subscriptions/$subscriptionId"
        
    foreach ($assignment in $assignments) {
        Write-Verbose "Assigning policy $($assignment.name)"
        try{
            $polas = Get-AzureRmPolicyAssignment -Name $assignment.name -Scope $scope -ErrorAction SilentlyContinue
        }catch {Write-Verbose "Assignment does not exist."}
        if ($polas -eq $null) {
            Write-Verbose "No assignment exists. Adding..."
            $definition = Get-AzureRmPolicySetDefinition -Name $name
            $null = New-AzureRmPolicyAssignment -Name $assignment.name `
                -DisplayName $assignment.displayName `
                -Scope $scope -PolicySetDefinition $definition
                Write-Verbose "Added assignment"
        }else {
            Write-Verbose "Assignment exists."
        }
    }
}

function Set-PolicySet {
    param (
        [string]$name,
        [string]$displayName,
        [string]$description,
        [string]$templateFile
    )

    $rdef = $null
    try {
        $rdef = Get-AzureRmPolicySetDefinition -Name $name -ErrorAction SilentlyContinue
        if ($rdef -ne $null -and $resource.update) {
            Write-Verbose "Updating policy defintion for $name"
            $policyset = Set-AzureRmPolicySetDefinition -Name $name -DisplayName $displayName `
                -Description $description -PolicyDefinition $templateFile 
        }
        elseif ($rdef -eq $null) {
            Write-Verbose "Creating policy definition $name"
            $policyset = New-AzureRmPolicySetDefinition -Name $name -DisplayName $displayName `
                -Description $description -PolicyDefinition $templateFile        
        }
        else {
            Write-Verbose "Policy definition $name exists and not updated"
            return
        }
    }
    catch {
        Write-Verbose "Policy definition $name does not exist"
    }
}

function Set-Resource {
    param(
        [object]$resource
    )
    $resourceType = (Get-Item -Path $PSScriptRoot).Parent.Name
    $templateFile = Get-ProjectTemplateFilePath -resourceType $resource.ResourceType -fileName $resource.templateFileName

    Write-Verbose "Template file is $templateFile"    
    
    if ($resource.subtype -eq "policyset") {
        $policydefintion = $resource.parameters | Where-Object {$_.type -eq "policydefinition"}
        if ($policydefintion -eq $null) {throw "Policy definition is empty"}
        $name = $policydefintion.name
        $displayName = $policydefintion.displayName
        $description = $policydefintion.description

        Set-PolicySet -name $name -displayName $displayName -description $description -templateFile $templateFile

        $assignments = $resource.parameters | Where-Object {$_.type -eq "assignment"}
        Set-Assignment -name $name -assignments $assignments
    } else {
        $templateParameterFile = Get-ProjectTemplateFilePath -resourceType $resource.ResourceType -fileName $resource.templateParameterFileName
        Write-Verbose "Template parameter file is $templateParameterFile"
        $policydefintion = $resource.parameters | Where-Object {$_.type -eq "policydefinition"}
        if ($policydefintion -eq $null) {throw "Policy definition is empty"}
        $name = $policydefintion.name
        $displayName = $policydefintion.displayName
        $description = $policydefintion.description

        Write-Verbose "New PolicyDefinition $name"
        $definition = New-AzureRmPolicyDefinition -Name $name -DisplayName $displayName -description $description -Policy $templateFile -Parameter $templateParameterFile -Mode All

        $subscriptionId = Get-SubscriptionId
        $scope = "/subscriptions/$subscriptionId"
    
        $assignment = $resource.parameters | Where-Object {$_.type -eq "assignment"}
        if ($assignment -eq $null) {throw "Assignment is empty"}
        $subnetIds = $assignment.parameters | Where-Object {$_.name -eq "subnetIds"}
        $assignment = New-AzureRMPolicyAssignment -Name $assignment.name -Scope $scope -subnetIds $subnetIds.value -PolicyDefinition $definition           
    }
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName


