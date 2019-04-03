# https://www.tensorflow.org/alpha/tutorials/keras/basic_classification

from __future__ import absolute_import, division, print_function

import json
import numpy as np
import os
import pickle
# TensorFlow and tf.keras
import tensorflow as tf
from tensorflow import keras

from azureml.core.model import Model

def init():
    global model
    # retrieve the path to the model file using the model name
    model_path = Model.get_model_path('tf_fmnist')
    model = keras.models.load_model(model_path)

def run(raw_data):
    data = np.array(json.loads(raw_data)['data'])
    # make prediction
    predictions_single = model.predict(data)

        # send a random row from the test set to score
    output_data = "{\"result\": " + str(list(predictions_single.tolist())) + "}"
    
    # you can return any data type as long as it is JSON-serializable
    return output_data
    