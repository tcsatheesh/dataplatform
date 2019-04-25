import os
import utils
import pickle
import argparse
import collections
import urllib.request

from azureml.train.estimator import Estimator
from azureml.core import Workspace
from azureml.core import Experiment
from azureml.core.compute import AmlCompute
from azureml.core.compute import ComputeTarget
from azureml.core.model import Model
from azureml.core.webservice import AciWebservice
from azureml.core.webservice import Webservice
from azureml.core.image import ContainerImage

def deployWebservice(ws,args,folders):
    # this section requries that the processing is done in the directory where the execution script and the conda_file resides
    os.chdir(folders.script_folder) 
    model=Model(ws, args.modelName)
    aciconfig = AciWebservice.deploy_configuration(
                                                   cpu_cores=args.cpuCores, 
                                                   memory_gb=args.memoryGB
                                                   )
    # configure the image
    image_config = ContainerImage.image_configuration(execution_script=args.scoringScript, 
                                                    runtime="python", 
                                                    conda_file=args.environmentFileName)
    service = Webservice.deploy_from_model(workspace=ws,
                                        name=args.webserviceName,
                                        deployment_config=aciconfig,
                                        models=[model],
                                        image_config=image_config)
    service.wait_for_deployment(show_output=True)
    return service.scoring_uri

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--projectFolder', required=True)
    parser.add_argument('--experimentName', required=True)
    parser.add_argument('--modelName', required=True)
    parser.add_argument('--modelFilePath', required=True)
    parser.add_argument('--modelFileName', required=True)
    parser.add_argument('--webserviceName', required=True)
    parser.add_argument('--config', default='config.json')
    parser.add_argument('--spconfig', default='spconfig.json')
    parser.add_argument('--aml_config_dir', default='aml_config')
    parser.add_argument('--cpuCores', type=int, default=1)
    parser.add_argument('--memoryGB', type=int, default=1)
    parser.add_argument('--scoringScript', default='score.py') 
    parser.add_argument('--environmentFileName', default='score_environment.yml')   
    parser.add_argument('--verbose', dest='verbose', action='store_true')
    parser.add_argument('--version', action='version', version='%(prog)s 1.0')
    args = parser.parse_args()

    args.projectFolder = utils.getProjectFolderFullPath(args)
    folders = utils.getFolders(args)
    utils.setConfigFiles(args)
    
    if (args.verbose):
        print ("Current working directory  : {0}".format(utils.getcwd(args)))
        print ("Experiment name            : {0}".format(args.experimentName))
        print ("Model name                 : {0}".format(args.modelName))
        print ("Project root folder        : {0}".format(args.projectFolder))
        print ("Project script folder      : {0}".format(folders.script_folder))
        print ("Project data folder        : {0}".format(folders.data_folder))
        print ("Project outputs folder     : {0}".format(folders.output_folder))
        print ("AML config file            : {0}".format(args.config))
        print ("AML config dir             : {0}".format(args.aml_config_dir))
        print ("Model file path            : {0}".format(args.modelFilePath))
        print ("Model file name            : {0}".format(args.modelFileName))
        print ("Webservice name            : {0}".format(args.webserviceName))
        print ("Number of CPU cores        : {0}".format(args.cpuCores))
        print ("Memory in GB               : {0}".format(args.memoryGB))
        print ("Scoring script             : {0}".format(args.scoringScript))
        print ("Environment filename       : {0}".format(args.environmentFileName))
        print ("Verbose value              : {0}".format(args.verbose))

    svc_pr = utils.loadAuthCredentials(args)
    ws = Workspace.from_config(path=args.config, auth=svc_pr)
    scoring_uri = deployWebservice(ws,args,folders)
    print("Scoring url                 : {0}".format(scoring_uri))