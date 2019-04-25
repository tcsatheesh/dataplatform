import os
import json
import collections

from azureml.core.authentication import ServicePrincipalAuthentication

def getcwd(args):
    currentFile = __file__
    realPath = os.path.realpath(currentFile)
    dirPath = os.path.dirname(realPath)
    return dirPath

def getFolders(args):
    data_folder = os.path.join(args.projectFolder, 'data')
    os.makedirs(data_folder, exist_ok=True)
    script_folder = os.path.join(args.projectFolder, "scripts")
    os.makedirs(script_folder, exist_ok=True)
    output_folder = os.path.join(args.projectFolder, "outputs")
    os.makedirs(output_folder, exist_ok=True)
    folders = collections.namedtuple('Folders', ['script_folder','data_folder', 'output_folder'])
    f = folders(script_folder=script_folder, data_folder=data_folder, output_folder=output_folder)
    return f

def getProjectFolderFullPath(args):
    cwd = getcwd(args)
    parentdir = os.path.dirname(cwd)
    return os.path.join(parentdir, args.projectFolder)

def setConfigFiles(args):
    cwd = getcwd(args)
    parentdir = os.path.dirname(cwd)    
    args.config = os.path.join(parentdir,args.aml_config_dir, args.config)
    args.spconfig = os.path.join(parentdir,args.aml_config_dir,args.spconfig)

def setDependencies(args,folders):
    args.conda_dependencies_file_path = os.path.join(folders.script_folder,args.conda_dependencies_file_path)
    args.pip_requirements_file_path = os.path.join(folders.script_folder,args.pip_requirements_file_path)

def loadAuthCredentials(args):
    with open(args.spconfig) as jsonFile:
        data = json.load(jsonFile)
    tenantid = data['tenantid']
    applicationid = data['applicationid']
    password = data['password']

    if (args.verbose):
        print ("Tenant Id                  : {0}".format(tenantid))
        print ("Application Id is          : {0}".format(applicationid))

    svc_pr = ServicePrincipalAuthentication(tenantid,
                                            applicationid,
                                            password)
    return svc_pr
