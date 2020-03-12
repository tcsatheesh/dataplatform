param
(
    [Parameter (Mandatory = $false)]
    [object] $WebhookData
)
    
# If runbook was called from Webhook, WebhookData will not be null.
if ($WebhookData) {	
    # Check header for message to validate request
    if ($WebhookData.RequestHeader.message -eq 'StartedbyDataFactory') {
        Write-Output "Header has required information"
    }
    else {
        Write-Output "Header missing required information";
        exit;
    }
    
    # Retrieve VM's from Webhook request body
    $atmParameters = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)
    Write-Output "CredentialName: $($atmParameters.CredentialName)"
    Write-Output "AnalysisServicesDatabaseName: $($atmParameters.AnalysisServicesDatabaseName)"
    Write-Output "AnalysisServicesServer: $($atmParameters.AnalysisServicesServer)"
    Write-Output "AnalysisServicesRolloutEnvironment: $($atmParameters.AnalysisServicesRolloutEnvironment)"
    Write-Output "DatabaseRefreshType: $($atmParameters.DatabaseRefreshType)"
    
    $Credential = Get-AutomationPSCredential -Name $atmParameters.CredentialName
    
    $TenantId = $atmParameters.TenantId
    $databaseName = $atmParameters.AnalysisServicesDatabaseName
    $analysisServer = $atmParameters.AnalysisServicesServer
    $analysisSeverRolloutEnvironment = $atmParameters.AnalysisServicesRolloutEnvironment
    $refreshType = $atmParameters.DatabaseRefreshType
    
    Add-AzureAnalysisServicesAccount -Credential $Credential -ServicePrincipal -TenantId $TenantId -RolloutEnvironment $analysisSeverRolloutEnvironment
    Invoke-ProcessASDatabase -DatabaseName $databaseName -RefreshType $refreshType -Server $analysisServer
}
else {
    $Credential = Get-AutomationPSCredential -Name "ServicePrincipal"

    $TenantId = Get-AutomationVariable -Name "TenantId"
    $databaseName = Get-AutomationVariable -Name "AnalysisServicesDatabaseName"
    $analysisServer = Get-AutomationVariable -Name "AnalysisServicesServer"
    $analysisSeverRolloutEnvironment = Get-AutomationVariable -Name "AnalysisServicesRolloutEnvironment"
    $refreshType = Get-AutomationVariable -Name "DatabaseRefreshType"

    Add-AzureAnalysisServicesAccount -Credential $Credential -ServicePrincipal -TenantId $TenantId -RolloutEnvironment $analysisSeverRolloutEnvironment
    Invoke-ProcessASDatabase -DatabaseName $databaseName -RefreshType $refreshType -Server $analysisServer
}