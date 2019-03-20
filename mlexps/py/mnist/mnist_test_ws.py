import json

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

def deployWebService(ws, args, folders):
    # this section requries that the processing is done in the directory where the execution script and the conda_file resides
    os.chdir(folders.script_folder) 
    if (args.verbose):
        print ("Current working directory: {0}".format(os.getcwd()))
    model=Model(ws, args.modelName)
    aciconfig = AciWebservice.deploy_configuration(cpu_cores=args.cpuCores, 
                                               memory_gb=args.memoryGB, 
                                               tags={"data": "MNIST",  "method" : "sklearn"}, 
                                               description='Predict MNIST with sklearn')
    if (args.verbose):
        print("Deploy ACI Webservice configuration.")

    # configure the image
    image_config = ContainerImage.image_configuration(execution_script=args.scoringScript, 
                                                    runtime="python", 
                                                    conda_file=args.environmentFileName)
    if (args.verbose):
        print ("Deploy container image.")
    service = Webservice.deploy_from_model(workspace=ws,
                                        name=args.webserviceName,
                                        deployment_config=aciconfig,
                                        models=[model],
                                        image_config=image_config)
    if (args.verbose):
        print ("Deploy webservice from model")
    service.wait_for_deployment(show_output=True)
    if (args.verbose):
        print("Scoring url: {0}".format(service.scoring_uri))
    return service

def testWS(ws,args,folders,service):
        # load the test data
    X_test = load_data(os.path.join(folders.data_folder, 'test-images.gz'), False) / 255.0
    y_test = load_data(os.path.join(folders.data_folder, 'test-labels.gz'), True).reshape(-1)

    # find 30 random samples from test set
    n = 30
    sample_indices = np.random.permutation(X_test.shape[0])[0:n]

    test_samples = json.dumps({"data": X_test[sample_indices].tolist()})
    test_samples = bytes(test_samples, encoding='utf8')

    # predict using the deployed model
    result = service.run(input_data=test_samples)

    # compare actual value vs. the predicted values:
    i = 0
    plt.figure(figsize = (20, 1))

    for s in sample_indices:
        plt.subplot(1, n, i + 1)
        plt.axhline('')
        plt.axvline('')
        
        # use different color for misclassified sample
        font_color = 'red' if y_test[s] != result[i] else 'black'
        clr_map = plt.cm.gray if y_test[s] != result[i] else plt.cm.Greys
        
        plt.text(x=10, y =-10, s=result[i], fontsize=18, color=font_color)
        plt.imshow(X_test[s].reshape(28, 28), cmap=clr_map)
        
        i = i + 1
    plt.show()

def testWebService(ws,args,folders):
    services = Webservice.list(workspace=ws, model_name=args.modelName)
    if (len(services) == 0):
        print ("Webservice is not deployed.")        
        service = deployWebService(ws,args,folders)
        testWS(ws,args,folders,service)
    else:
        print ("Webservice is deployed. Use the http version to test.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-c', '--config')
    parser.add_argument('--experimentName', default='exp02')
    parser.add_argument('--clusterName', default='cpucluster')
    parser.add_argument('--minNodes', type=int, default=0)
    parser.add_argument('--maxNodes', type=int, default=1)
    parser.add_argument('--clusterSku', default='Standard_D2_v2')
    parser.add_argument('--modelName', default='sklearn_mnist')
    parser.add_argument('--entryScript', default='train.py')
    parser.add_argument('--condaPackages', default='scikit-learn')
    parser.add_argument('--dsDataFolder', default='mnist')
    parser.add_argument('--regularization', type=float, default=0.04)
    parser.add_argument('--modelPath', default='outputs/sklearn_mnist_model.pkl')
    parser.add_argument('--modelFileName', default='sklearn_mnist_model.pkl')
    parser.add_argument('--cpuCores', type=int, default=1)
    parser.add_argument('--memoryGB', type=int, default=1)
    parser.add_argument('--scoringScript', default='score.py') 
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
    testWebService(ws,args,folders)
