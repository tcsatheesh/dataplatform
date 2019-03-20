import argparse
import requests
import os
import collections
import numpy as np
import matplotlib.pyplot as plt
from scripts.utils import load_data

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

def score(scoring_uri, folders):
    X_test = load_data(os.path.join(folders.data_folder, 'test-images.gz'), False) / 255.0
    y_test = load_data(os.path.join(folders.data_folder, 'test-labels.gz'), True).reshape(-1)

    # send a random row from the test set to score
    random_index = np.random.randint(0, len(X_test)-1)
    input_data = "{\"data\": [" + str(list(X_test[random_index])) + "]}"

    headers = {'Content-Type':'application/json'}

    # for AKS deployment you'd need to the service key in the header as well
    # api_key = service.get_key()
    # headers = {'Content-Type':'application/json',  'Authorization':('Bearer '+ api_key)} 

    resp = requests.post(scoring_uri, input_data, headers=headers)

    print("POST to url", scoring_uri)
    #print("input data:", input_data)
    print("label:", y_test[random_index])
    print("prediction:", resp.text)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--scoring_uri', default='http://40.81.12.100:80/score')
    parser.add_argument('-v', '--verbose', dest='verbose', action='store_true')
    parser.add_argument('--version', action='version', version='%(prog)s 1.0')
    args = parser.parse_args()
    folders = createFolders()
    score(args.scoring_uri,folders)