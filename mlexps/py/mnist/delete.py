import argparse
import urllib.request
import os
from azureml.train.estimator import Estimator
from azureml.core import Workspace
from azureml.core import Experiment
from azureml.core.compute import AmlCompute
from azureml.core.compute import ComputeTarget
from azureml.core.model import Model
import os
import collections
import pickle
from sklearn.externals import joblib
from sklearn.metrics import confusion_matrix
from scripts.utils import load_data
import numpy as np
import matplotlib.pyplot as plt
from azureml.core.webservice import AciWebservice
from azureml.core.webservice import Webservice
from azureml.core.image import ContainerImage
 

def getwd():
    currentFile = __file__
    realPath = os.path.realpath(currentFile)
    dirPath = os.path.dirname(realPath)
    return dirPath

def createFolders():
    data_folder = os.path.join(getwd(), 'data')
    os.makedirs(data_folder, exist_ok=True)
    script_folder = os.path.join(getwd(), "scripts")
    os.makedirs(script_folder, exist_ok=True)
    output_folder = os.path.join(getwd(), "outputs")
    os.makedirs(output_folder, exist_ok=True)
    folders = collections.namedtuple('Folders', ['script_folder','data_folder', 'output_folder'])
    f = folders(script_folder=script_folder, data_folder=data_folder, output_folder=output_folder)
    return f


def deleteWebService(ws,args,folders):
    # this section requries that the processing is done in the directory where the execution script and the conda_file resides
    os.chdir(folders.script_folder) 
    if (args.verbose):
        print ("Current working directory: {0}".format(os.getcwd()))
    services = Webservice.list(workspace=ws, model_name=args.modelName)
    if (len(services) == 0):
        print ("Webservice is not deployed.")        
    else:
        print ("Webservice is deployed")
        services[0].delete()
        print ("Deleted webservice")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-c', '--config')
    parser.add_argument('--experimentName', default='exp02')
    parser.add_argument('--clusterName', default='cpucluster')
    parser.add_argument('--minNodes', type=int, default=0)
    parser.add_argument('--maxNodes', type=int, default=1)
    parser.add_argument('--clusterSku', default='Standard_D2_v2')
    parser.add_argument('--modelName', default='sklearn_mnist')
    parser.add_argument('--entryScript', default='mnist_train.py')
    parser.add_argument('--condaPackages', default='scikit-learn')
    parser.add_argument('--dsDataFolder', default='mnist')
    parser.add_argument('--regularization', type=float, default=0.04)
    parser.add_argument('--modelPath', default='outputs/sklearn_mnist_model.pkl')
    parser.add_argument('--modelFileName', default='sklearn_mnist_model.pkl')
    parser.add_argument('--cpuCores', type=int, default=1)
    parser.add_argument('--memoryGB', type=int, default=1)
    parser.add_argument('--scoringScript', default='mnist_score.py') 
    parser.add_argument('--environmentFileName', default='env.yml')   
    parser.add_argument('--webserviceName', default='sklearn-mnist-svc')       
    parser.add_argument('-v', '--verbose', dest='verbose', action='store_true')
    parser.add_argument('--version', action='version', version='%(prog)s 1.0')
    args = parser.parse_args()
    folders = createFolders()
    if (args.verbose):
        print ("config file: {0}".format(args.config))
        print ("verbose value: {0}".format(args.verbose))
        print ("local script folder: {0}".format(folders.script_folder))
        print ("local data folder: {0}".format(folders.data_folder))
        print ("local output folder: {0}".format(folders.output_folder))
        
    ws = Workspace.from_config(path=args.config)
    deleteWebService(ws,args,folders)
    