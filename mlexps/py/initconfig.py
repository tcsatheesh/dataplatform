import argparse
import os
import json
import azureml.core
from azureml.core import Workspace


def getResourceGroupName(projectDirPath):
    resourceGroupParameterFilePath = projectDirPath + os.sep + "resourcegroups.parameters.json"
    with open(resourceGroupParameterFilePath, encoding='utf-8-sig') as jsonData:
        projectParameters = json.load(jsonData)
    params = projectParameters['parameters']['resources']['value']
    return params['name']

def getWorkspaceName(projectDirPath, resourceType):
    resourceParameterFilePath = projectDirPath + os.sep + resourceType + ".parameters.json"
    with open(resourceParameterFilePath, encoding='utf-8-sig') as jsonData:
        resourceParameters = json.load(jsonData)
    params = resourceParameters['parameters']['resources']['value']
    return params['name']

def setWorkspace(projectParameterFilePath, templateDirPath, verbose):
    projectDirPath = os.path.dirname(projectParameterFilePath)
    if (verbose):
        print ("Project Parameter Directoru: {0}".format(projectDirPath))
        print ("Project Parameter File path: {0}".format(projectParameterFilePath))
        print ("Template directory: {0}".format(templateDirPath))
    projectParameters = None
    with open(projectParameterFilePath, encoding='utf-8-sig') as jsonData:
        projectParameters = json.load(jsonData)
    params = projectParameters['parameters']['resources']['value']
    resourceList = None
    typeValue = None
    subscriptionId = None
    for item in params:
        if (item['type'] == 'envtype'):
            typeValue = item['value']
        if (typeValue is not None):
            if (item['type'] == typeValue ):
                resourceList = item["resources"]
        if (item['type'] == 'subscription'):
            subscriptionId = item['id']
    if (verbose):
        print (resourceList)
    resourceGroupName = getResourceGroupName(projectDirPath)
    workspaceName = getWorkspaceName(projectDirPath, "mlexps")
    if (verbose):
        print("Resource Group Name: {0}".format(resourceGroupName))
        print("Workspace Name: {0}".format(workspaceName))
        print("Subscription Id: {0}".format(subscriptionId))
        print("Azure ML SDK version:", azureml.core.VERSION)

    ws = Workspace.get(name=workspaceName,
                    subscription_id=subscriptionId,
                    resource_group=resourceGroupName)
    ws.get_details()
    ws.write_config()

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-p', '--projectParameterFile')
    parser.add_argument('-v', '--verbose', dest='verbose', action='store_true')
    parser.add_argument('--version', action='version', version='%(prog)s 1.0')
    args = parser.parse_args()
    currentFile = __file__
    realPath = os.path.realpath(currentFile)
    dirPath = os.path.dirname(realPath)
    rootDirPath = os.path.abspath(dirPath + os.sep + ".." + os.sep + "..")
    templateDirPath = os.path.abspath(dirPath + os.sep + ".." + os.sep + "templates")
    projectParameterFilePath = os.path.realpath(args.projectParameterFile)
    if (args.verbose):
        print ("Project Parameter File value: {0}".format(args.projectParameterFile))
        print ("Verbose value: {0}".format(args.verbose))
        print ("Script directory: {0}".format(dirPath))
        print ("Root directory: {0}".format(rootDirPath))        
        print ("Azure ML Version: {0}".format(azureml.core.VERSION))
    setWorkspace(projectParameterFilePath, templateDirPath, args.verbose)


    
