
# 00000003-0000-0ff1-ce00-000000000000 is the AppId for SharePoint Online, call Get-AzureADServicePrincipal by itself to find other AppIds
$SPOApi = Get-AzureADServicePrincipal -Filter "AppId eq '00000003-0000-0ff1-ce00-000000000000'"
$SPOApi.AppRoles