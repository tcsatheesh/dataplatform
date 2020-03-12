import os
import json
import pickle
import argparse
import collections
import urllib.request

import numpy as np
import matplotlib.pyplot as plt

from sklearn.externals import joblib
from sklearn.metrics import confusion_matrix
from scripts.utils import load_data

from azureml.core import Workspace
from azureml.core.model import Model
from azureml.core.authentication import ServicePrincipalAuthentication

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

def downloadModel(ws,args,folders):
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

def teestModel(args, folders):
    # load the test data
    X_test = load_data(os.path.join(folders.data_folder, 'test-images.gz'), False) / 255.0
    y_test = load_data(os.path.join(folders.data_folder, 'test-labels.gz'), True).reshape(-1)

    # predic test data
    clf = joblib.load( os.path.join(folders.output_folder, args.modelFileName))
    y_hat = clf.predict(X_test)

    # examine the confusion matrix
    conf_mx = confusion_matrix(y_test, y_hat)
    print(conf_mx)
    print('Overall accuracy:', np.average(y_hat == y_test))
    return conf_mx

def showConfusionMatrix(conf_mx):
    row_sums = conf_mx.sum(axis=1, keepdims=True)
    norm_conf_mx = conf_mx / row_sums
    np.fill_diagonal(norm_conf_mx, 0)

    fig = plt.figure(figsize=(8,5))
    ax = fig.add_subplot(111)
    cax = ax.matshow(norm_conf_mx, cmap=plt.cm.bone)
    ticks = np.arange(0, 10, 1)
    ax.set_xticks(ticks)
    ax.set_yticks(ticks)
    ax.set_xticklabels(ticks)
    ax.set_yticklabels(ticks)
    fig.colorbar(cax)
    plt.ylabel('true labels', fontsize=14)
    plt.xlabel('predicted values', fontsize=14)
    plt.savefig('conf.png')
    plt.show()

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

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', default='..\\aml_config\\config.json')
    parser.add_argument('--spconfig', default='..\\aml_config\\spconfig.json')
    parser.add_argument('--modelName', default='mnist2')
    parser.add_argument('--modelPath', default='outputs/sklearn_mnist_model.pkl')
    parser.add_argument('--modelFileName', default='sklearn_mnist_model.pkl')
    parser.add_argument('-v', '--verbose', dest='verbose', action='store_true')
    parser.add_argument('--version', action='version', version='%(prog)s 1.0')
    args = parser.parse_args()
    folders = createFolders()
    args.config = os.path.join(getwd(),args.config)
    args.spconfig = os.path.join(getwd(),args.spconfig)

    if (args.verbose):
        print ("config file: {0}".format(args.config))
        print ("verbose value: {0}".format(args.verbose))
        print ("local script folder: {0}".format(folders.script_folder))
        print ("local data folder: {0}".format(folders.data_folder))
        print ("local output folder: {0}".format(folders.output_folder))
        
    svc_pr = loadAuthCredentials(args)        
    ws = Workspace.from_config(path=args.config, auth=svc_pr)
    downloadModel(ws,args,folders)
    conf_mx = teestModel(args,folders)
    showConfusionMatrix(conf_mx)