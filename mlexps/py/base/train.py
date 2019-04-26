import os
import utils
import json
import yaml
import argparse
import collections
import urllib.request

from azureml.core import Workspace
from azureml.core import Experiment
from azureml.core.compute import AmlCompute
from azureml.train.estimator import Estimator
from azureml.core.compute import ComputeTarget
from azureml.core.authentication import ServicePrincipalAuthentication


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
    parser.add_argument('--settingsFile',                    default=argsmain.settingsFile)
    parser.add_argument('--experimentName',                 default=data['experimentName'])
    parser.add_argument('--modelName',                      default=data['modelName'])
    parser.add_argument('--remoteDataFolder',               default=data['remoteDataFolder'])
    parser.add_argument('--modelFilePath',                  default=data['modelFilePath'])
    parser.add_argument('--config',                         default=data['config'])
    parser.add_argument('--spconfig',                       default=data['spconfig'])
    parser.add_argument('--aml_config_dir',                 default=data['aml_config_dir'])
    parser.add_argument('--clusterName',                    default=data['clusterName'])
    parser.add_argument('--clusterSku',                     default=data['clusterSku'])
    parser.add_argument('--minNodes', type=int,             default=data['minNodes'])
    parser.add_argument('--maxNodes', type=int,             default=data['maxNodes'])
    parser.add_argument('--useGPU',   type=bool,            default=data['useGPU'])
    parser.add_argument('--userManaged', type=bool,         default=data['userManaged'])
    parser.add_argument('--useDocker', type=bool,           default=data['useDocker'])
    parser.add_argument('--mountDataStore', type=bool,      default=data['mountDataStore'])
    parser.add_argument('--entryScript',                    default=data['entryScript'])
    parser.add_argument('--conda_dependencies_file_path',   default=data['conda_dependencies_file_path'])
    parser.add_argument('--pip_requirements_file_path',     default=data['pip_requirements_file_path'])
    parser.add_argument('--uploadDataToCloud', type=bool,   default=data['uploadDataToCloud'])
    parser.add_argument('--verbose', type=bool,             default=data['verbose'])
    parser.add_argument('--version', action='version', version='%(prog)s 1.0')
    args = parser.parse_args()
    return args

def uploadDataToCloud(ws,args,folders):
    ds = ws.get_default_datastore()
    print ("Datastore type             : {0}".format(ds.datastore_type))
    print ("Datastore account name     : {0}".format(ds.account_name))
    print ("Datastore container name   : {0}".format(ds.container_name))
    ds.upload(
              src_dir=folders.data_folder, 
              target_path=args.remoteDataFolder, 
              overwrite=True, 
              show_progress=True
              )


def createCompute(ws, args):
    compute_name = args.clusterName

    if compute_name in ws.compute_targets:
        compute_target = ws.compute_targets[compute_name]
        if compute_target and type(compute_target) is AmlCompute:
            print("Found compute target       : {0}".format( compute_name))
    else:
        print ("Compute target {0} not found. Create one manually first.".format(compute_name))
        # compute_min_nodes = args.minNodes
        # compute_max_nodes = args.maxNodes
        # vm_size = args.clusterSku
        # print("Creating a new compute target {0}.".format(compute_name))
        # provisioning_config = AmlCompute.provisioning_configuration(vm_size = vm_size,
        #                                                             min_nodes = compute_min_nodes, 
        #                                                             max_nodes = compute_max_nodes)
        # # create the cluster
        # compute_target = ComputeTarget.create(ws, compute_name, provisioning_config)        
        # # can poll for a minimum number of nodes and for a specific timeout. 
        # # if no min node count is provided it will use the scale settings for the cluster
        # compute_target.wait_for_completion(show_output=True, min_node_count=None, timeout_in_minutes=20)
        
        # if (args.verbose):
        #     # For a more detailed view of current AmlCompute status, use get_status()
        #     print(compute_target.get_status().serialize())
    return compute_target

def createEstimator(ws, args, folders):    
    data_folder = args.remoteDataFolder
    if (args.mountDataStore == True):
        ds = ws.get_default_datastore()
        data_folder = ds.path(args.remoteDataFolder).as_mount()

    if (args.verbose):
        print("Remote data folder         : {0}".format(data_folder))

    script_params = {
        '--data-folder': data_folder,
        '--modelFilePath': args.modelFilePath        
    }

    compute_target = createCompute(ws,args)

    conda_packages = []
    ## hack until conda_dependencies_file_path works
    with open(args.conda_dependencies_file_path, 'r') as stream:
        yml = yaml.safe_load(stream)
        conda_packages = yml['dependencies']
    ##

    est = Estimator(
                    source_directory=folders.script_folder,
                    script_params=script_params,
                    compute_target=compute_target,
                    entry_script=args.entryScript,
                    use_gpu=args.useGPU,
                    user_managed=args.userManaged,
                    use_docker=args.useDocker,
                    conda_packages=conda_packages,
                    pip_requirements_file_path=args.pip_requirements_file_path
                    )

    return est

def createExperiment(ws, args, folders):
    # Create a new experiment in your workspace.
    exp = Experiment(workspace=ws, name=args.experimentName)
    est = createEstimator(ws, args, folders)

    # Start a run and start the logging service.
    experiment = exp.submit(config=est)

    # specify show_output to True for a verbose log
    experiment.wait_for_completion(show_output=True)
    print ("Experiment metrics         : {0}".format(experiment.get_metrics()))
    print ("Experiment file names      : {0}".format(experiment.get_file_names()))

    # register model 
    model = experiment.register_model(model_name=args.modelName, model_path=args.modelFilePath)
    print ("Model Name                 : {0}".format(model.name))
    print ("Model ID                   : {0}".format(model.id))
    print ("Model Version              : {0}".format(model.version))

if __name__ == '__main__':

    args = parseArgs()

    args.projectFolder = utils.getProjectFolderFullPath(args)
    folders = utils.getFolders(args)
    utils.setConfigFiles(args)
    utils.setDependencies(args,folders)
    
    if (args.verbose):
        print ("Current working directory  : {0}".format(utils.getcwd()))
        print ("Experiment name            : {0}".format(args.experimentName))
        print ("Model name                 : {0}".format(args.modelName))
        print ("Project root folder        : {0}".format(args.projectFolder))
        print ("Project script folder      : {0}".format(folders.script_folder))
        print ("Project data folder        : {0}".format(folders.data_folder))
        print ("Project outputs folder     : {0}".format(folders.output_folder))
        print ("AML config file            : {0}".format(args.config))
        print ("AML config dir             : {0}".format(args.aml_config_dir))
        print ("Service principal config   : {0}".format(args.spconfig))
        print ("Cluster name               : {0}".format(args.clusterName))
        print ("Cluster sku                : {0}".format(args.clusterSku))
        print ("Minimum nodes              : {0}".format(args.minNodes))
        print ("Maximum nodes              : {0}".format(args.maxNodes))
        print ("User managed               : {0}".format(args.userManaged))
        print ("Use docker                 : {0}".format(args.useDocker))
        print ("Entry script               : {0}".format(args.entryScript))
        print ("Remote Data Folder         : {0}".format(args.remoteDataFolder))
        print ("Model output file path     : {0}".format(args.modelFilePath))
        print ("Conda dependencies         : {0}".format(args.conda_dependencies_file_path))
        print ("Pip dependencies           : {0}".format(args.pip_requirements_file_path))
        print ("Upload data to cloud       : {0}".format(args.uploadDataToCloud))
        print ("Verbose value              : {0}".format(args.verbose))

    svc_pr = utils.loadAuthCredentials(args)
    ws = Workspace.from_config(path=args.config, auth=svc_pr)
    if (args.uploadDataToCloud == True):
        uploadDataToCloud(ws, args, folders)
    createExperiment(ws, args,folders)    
