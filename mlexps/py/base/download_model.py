import os
import json
import utils
import pickle
import argparse
import collections
import urllib.request

from azureml.core import Workspace
from azureml.core.model import Model
from azureml.core.authentication import ServicePrincipalAuthentication

def download_model(ws,args,folders):
    file_path = os.path.join(folders.output_folder, args.modelFileName)
    if (os.path.isfile(file_path)):
        print ("Model file already exists in: {0}".format(file_path))
    else:
        print ("Model file does not exist in: {0}".format(file_path))
        model=Model(ws, name=args.modelName)
        model.download(target_dir=folders.output_folder, exist_ok=False)
    statinfo = os.stat(file_path)
    if (args.verbose):
        print(statinfo)

def parseArgs():
    parser = argparse.ArgumentParser()
    parser.add_argument('--projectFolder', required=True)
    parser.add_argument('--settingsFile', default="train_settings.json")
    argsmain = parser.parse_args()        
    
    projectFolder = utils.getProjectFolderFullPath(argsmain)
    settingsFilePath = os.path.join(projectFolder, argsmain.settingsFile)
    print ("Settings File Path         : {0}".format(settingsFilePath))
    with open(settingsFilePath) as settingsFile:
        data = json.load(settingsFile)

    parser = argparse.ArgumentParser()
    parser.add_argument('--projectFolder',                  default=argsmain.projectFolder)
    parser.add_argument('--settingsFile',                   default=argsmain.settingsFile)
    parser.add_argument('--modelName',                      default=data['modelName'])
    parser.add_argument('--modelFileName',                  default=data['modelFileName'])
    parser.add_argument('--modelFilePath',                  default=data['modelFilePath'])
    parser.add_argument('--config',                         default=data['config'])
    parser.add_argument('--spconfig',                       default=data['spconfig'])
    parser.add_argument('--aml_config_dir',                 default=data['aml_config_dir'])
    parser.add_argument('--verbose', type=bool,             default=data['verbose'])
    parser.add_argument('--version', action='version', version='%(prog)s 1.0')
    args = parser.parse_args()
    return args
        

if __name__ == '__main__': 
    args = parseArgs()

    args.projectFolder = utils.getProjectFolderFullPath(args)
    folders = utils.getFolders(args)
    utils.setConfigFiles(args)
    
    if (args.verbose):
        print ("Current working directory  : {0}".format(utils.getcwd()))
        print ("Model name                 : {0}".format(args.modelName))
        print ("Project root folder        : {0}".format(args.projectFolder))
        print ("Project script folder      : {0}".format(folders.script_folder))
        print ("Project data folder        : {0}".format(folders.data_folder))
        print ("Project outputs folder     : {0}".format(folders.output_folder))
        print ("AML config file            : {0}".format(args.config))
        print ("AML config dir             : {0}".format(args.aml_config_dir))
        print ("Service principal config   : {0}".format(args.spconfig))
        print ("Model output file path     : {0}".format(args.modelFilePath))
        print ("Verbose value              : {0}".format(args.verbose))
    svc_pr = utils.loadAuthCredentials(args)
    ws = Workspace.from_config(path=args.config, auth=svc_pr)
    download_model(ws,args,folders)
