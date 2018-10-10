# principals

Scripts to execute as a user administrator

### Concepts

Two Azure AD applications and services principals are created

1. Deployment Principal: This is used in deployment scripts to deploy project resources.
2. Application Principal: This is used for machine to machine access. The application principal has both access via client secret and via a client certificate. The client certificate is available in the local certificate store under Current User -> Personal

### Create

To create a new project and its principals

| Run Order | Script | Purpose |
| --------- | ------ | ------- |
|1.|New-Applications.ps1|Create a new project by running the  script|
|2.|Set-Applications.ps1|Create/Update the deployment and application principals by running the script.|
|3.|New-ADGroups.ps1|Create new AD groups parameter file by running the  script|
|4.|Set-ADGroups.ps1|Update the AD groups ids by running the script. If you want to create the groups in Azure AD rather than in on premises then pass the CreateNew paramter to this script|

### Remove

1. To remove the principals run the Remove-Applications.ps1 script
2. To remove the AD groups run the Remove-ADGroups.ps1 script