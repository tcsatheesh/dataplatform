from __future__ import absolute_import, division, print_function

import os
import json
import pickle
import collections
import argparse
import urllib.request
import numpy as np
import matplotlib.pyplot as plt

from azureml.core import Workspace
from azureml.core.model import Model
from azureml.core.authentication import ServicePrincipalAuthentication

# TensorFlow and tf.keras
import tensorflow as tf
from tensorflow import keras

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

def plot_image(i, predictions_array, true_label, img):
  predictions_array, true_label, img = predictions_array[i], true_label[i], img[i]
  plt.grid(False)
  plt.xticks([])
  plt.yticks([])
  
  plt.imshow(img, cmap=plt.cm.binary)

  predicted_label = np.argmax(predictions_array)
  if predicted_label == true_label:
    color = 'blue'
  else:
    color = 'red'
  
  class_names = ['T-shirt/top', 'Trouser', 'Pullover', 'Dress', 'Coat', 
            'Sandal', 'Shirt', 'Sneaker', 'Bag', 'Ankle boot']
 
  plt.xlabel("{} {:2.0f}% ({})".format(class_names[predicted_label],
                                100*np.max(predictions_array),
                                class_names[true_label]),
                                color=color)

def plot_value_array(i, predictions_array, true_label):
  predictions_array, true_label = predictions_array[i], true_label[i]
  plt.grid(False)
  plt.xticks([])
  plt.yticks([])
  thisplot = plt.bar(range(10), predictions_array, color="#777777")
  plt.ylim([0, 1]) 
  predicted_label = np.argmax(predictions_array)
 
  thisplot[predicted_label].set_color('red')
  thisplot[true_label].set_color('blue')

def testModel(args, folders):
    fashion_mnist = keras.datasets.fashion_mnist
    (train_images, train_labels), (test_images, test_labels) = fashion_mnist.load_data()

    class_names = ['T-shirt/top', 'Trouser', 'Pullover', 'Dress', 'Coat', 
            'Sandal', 'Shirt', 'Sneaker', 'Bag', 'Ankle boot']

    train_images = train_images / 255.0
    test_images = test_images / 255.0
    model = keras.models.load_model(args.modelPath)
    predictions = model.predict(test_images)
    i = args.selected_item
    plt.figure(figsize=(6,3))
    plt.subplot(1,2,1)
    plot_image(i, predictions, test_labels, test_images)
    plt.subplot(1,2,2)
    plot_value_array(i, predictions,  test_labels)
    _ = plt.xticks(range(10), class_names, rotation=45)
    plt.show()

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', default='..\\aml_config\\config.json')
    parser.add_argument('--spconfig', default='..\\aml_config\\spconfig.json')
    parser.add_argument('--modelName', default='fmnist')
    parser.add_argument('--modelPath', default='outputs/fmnist.h5')
    parser.add_argument('--modelFileName', default='fmnist.h5')
    parser.add_argument('--selected_item', type=int, default=0)
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
        
    svc_pr = loadAuthCredentials(args)        
    ws = Workspace.from_config(path=args.config, auth=svc_pr)
    downloadModel(ws,args,folders)
    testModel(args,folders)
