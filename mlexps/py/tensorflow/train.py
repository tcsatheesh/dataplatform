import argparse
import urllib.request
import os
from azureml.train.estimator import Estimator
from azureml.core import Workspace
from azureml.core import Experiment
from azureml.core.compute import AmlCompute
from azureml.core.compute import ComputeTarget
import os
import collections

def getwd():
    currentFile = __file__
    realPath = os.path.realpath(currentFile)
    dirPath = os.path.dirname(realPath)
    return dirPath

def createCompute(ws, args):
    # choose a name for your cluster
    compute_name = os.environ.get("AML_COMPUTE_CLUSTER_NAME", args.clusterName)
    compute_min_nodes = os.environ.get("AML_COMPUTE_CLUSTER_MIN_NODES", args.minNodes)
    compute_max_nodes = os.environ.get("AML_COMPUTE_CLUSTER_MAX_NODES", args.maxNodes)

    # This example uses CPU VM. For using GPU VM, set SKU to STANDARD_NC6
    vm_size = os.environ.get("AML_COMPUTE_CLUSTER_SKU", args.clusterSku)

    if compute_name in ws.compute_targets:
        compute_target = ws.compute_targets[compute_name]
        if compute_target and type(compute_target) is AmlCompute:
            print('found compute target. Using it. ' + compute_name)
    else:
        print('creating a new compute target...')
        provisioning_config = AmlCompute.provisioning_configuration(vm_size = vm_size,
                                                                    min_nodes = compute_min_nodes, 
                                                                    max_nodes = compute_max_nodes)

        # create the cluster
        compute_target = ComputeTarget.create(ws, compute_name, provisioning_config)
        
        # can poll for a minimum number of nodes and for a specific timeout. 
        # if no min node count is provided it will use the scale settings for the cluster
        compute_target.wait_for_completion(show_output=True, min_node_count=None, timeout_in_minutes=20)
        
        if (args.verbose):
            # For a more detailed view of current AmlCompute status, use get_status()
            print(compute_target.get_status().serialize())
    return compute_target

def createEstimator(ws, args, folders):
    ds = ws.get_default_datastore()
        
    if (args.verbose):
        print("cluster name: {0}".format(args.clusterName))
        print("min nodes: {0}".format(args.minNodes))
        print("max nodes: {0}".format(args.maxNodes))
        print("cluster sku: {0}".format(args.clusterSku))
        print("ds data folder: {0}".format(args.dsDataFolder))
        print("Regularization: {0}".format(args.regularization))
        print("entry script: {0}".format(args.entryScript))
        print("conda packages: {0}".format(args.condaPackages))

    script_params = {
        '--data-folder': ds.path(args.dsDataFolder).as_mount(),
        '--regularization': args.regularization
    }

    compute_target = createCompute(ws,args)

    est = Estimator(source_directory=folders.script_folder,
                    script_params=script_params,
                    compute_target=compute_target,
                    entry_script=args.entryScript,
                    conda_packages=['tensorflow', 'matplotlib'])

    if (args.verbose):
        print(ds.path(args.dsDataFolder).as_mount())
    return est

def createExperiment(ws, args, folders):
    if (args.verbose):
        print ("experiment Name: {0}".format(args.experimentName))

    # Create a new experiment in your workspace.
    exp = Experiment(workspace=ws, name=args.experimentName)
    est = createEstimator(ws, args, folders)
    # Start a run and start the logging service.
    experiment = exp.submit(config=est)
    return experiment

def runExperiment(experiment):
    experiment
    # specify show_output to True for a verbose log
    experiment.wait_for_completion(show_output=True)
    print(experiment.get_metrics())

def registerModel(experiment,args):
    print(experiment.get_file_names())
    # register model 
    model = experiment.register_model(model_name=args.modelName, model_path=args.modelPath)
    print("Model Name: {0}, Model ID: {1}, Model Version: {2}".format(model.name, model.id, model.version))

def createFolders():
    data_folder = os.path.join(getwd(), 'data')
    os.makedirs(data_folder, exist_ok=True)
    script_folder = os.path.join(getwd(), "scripts")
    os.makedirs(script_folder, exist_ok=True)
    folders = collections.namedtuple('Folders', ['script_folder','data_folder'])
    f = folders(script_folder=script_folder, data_folder=data_folder)
    return f

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-c', '--config')
    parser.add_argument('--experimentName', default='exp03')
    parser.add_argument('--clusterName', default='cpucluster')
    parser.add_argument('--minNodes', type=int, default=0)
    parser.add_argument('--maxNodes', type=int, default=1)
    parser.add_argument('--clusterSku', default='Standard_D2_v2')
    parser.add_argument('--modelName', default='tf_fmnist')
    parser.add_argument('--entryScript', default='fmnist_train.py')
    parser.add_argument('--condaPackages', default=['tensorflow','matplotlib'])
    parser.add_argument('--dsDataFolder', default='fmnist')
    parser.add_argument('--regularization', type=float, default=0.04)
    parser.add_argument('--modelPath', default='outputs/fmnist.h5')
    parser.add_argument('-v', '--verbose', dest='verbose', action='store_true')
    parser.add_argument('--version', action='version', version='%(prog)s 1.0')
    args = parser.parse_args()
    folders = createFolders()
    if (args.verbose):
        print ("config file: {0}".format(args.config))
        print ("verbose value: {0}".format(args.verbose))
        print ("local script folder: {0}".format(folders.script_folder))
        print ("local data folder: {0}".format(folders.data_folder))
    ws = Workspace.from_config(path=args.config)
    experiment = createExperiment(ws, args,folders)
    runExperiment(experiment)
    registerModel(experiment,args)
