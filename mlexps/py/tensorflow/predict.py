from __future__ import absolute_import, division, print_function

# TensorFlow and tf.keras
import tensorflow as tf
from tensorflow import keras
import argparse
import requests
import os
import collections
import numpy as np
import matplotlib.pyplot as plt
import json


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

def score(args, folders):
    fashion_mnist = keras.datasets.fashion_mnist
    (train_images, train_labels), (test_images, test_labels) = fashion_mnist.load_data()
    class_names = ['T-shirt/top', 'Trouser', 'Pullover', 'Dress', 'Coat', 
               'Sandal', 'Shirt', 'Sneaker', 'Bag', 'Ankle boot']
    train_images = train_images / 255.0
    test_images = test_images / 255.0
    selected_index = args.selected_item
    img = test_images[selected_index]
    img = (np.expand_dims(img,0))[0].tolist()    

    # send a random row from the test set to score
    input_data = "{\"data\": [" + str(list(img)) + "]}"
    
    headers = {'Content-Type':'application/json'}

    # for AKS deployment you'd need to the service key in the header as well
    # api_key = service.get_key()
    # headers = {'Content-Type':'application/json',  'Authorization':('Bearer '+ api_key)} 
    print("POST to url", args.scoring_uri)
    resp = requests.post(args.scoring_uri, input_data, headers=headers)
    #print("input data:", input_data)
    print("label:", class_names[test_labels[selected_index]])
    prediction_single = np.fromstring(resp.text.strip('[').strip(']'),dtype="float", sep=",")
    prediction_single = prediction_single[np.newaxis]
    print("prediction:", prediction_single)
    plot_value_array(0, prediction_single , test_labels)
    _ = plt.xticks(range(10), class_names, rotation=45)
    plt.show()

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--scoring_uri', default='http://52.157.20.197:80/score')
    parser.add_argument('--selected_item', type=int, default=0)
    parser.add_argument('-v', '--verbose', dest='verbose', action='store_true')
    parser.add_argument('--version', action='version', version='%(prog)s 1.0')
    args = parser.parse_args()
    folders = createFolders()
    score(args,folders)