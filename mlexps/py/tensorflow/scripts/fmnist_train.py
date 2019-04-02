# https://www.tensorflow.org/alpha/tutorials/keras/basic_classification

from __future__ import absolute_import, division, print_function

# TensorFlow and tf.keras
import tensorflow as tf
from tensorflow import keras

# Helper libraries
import numpy as np
import matplotlib.pyplot as plt
from azureml.core import Run

print(tf.__version__)

fashion_mnist = keras.datasets.fashion_mnist
(train_images, train_labels), (test_images, test_labels) = fashion_mnist.load_data()

class_names = ['T-shirt/top', 'Trouser', 'Pullover', 'Dress', 'Coat', 
               'Sandal', 'Shirt', 'Sneaker', 'Bag', 'Ankle boot']

train_images = train_images / 255.0

test_images = test_images / 255.0

def display25Images(train_images, train_labels, class_names):
    plt.figure(figsize=(10,10))
    for i in range(25):
        plt.subplot(5,5,i+1)
        plt.xticks([])
        plt.yticks([])
        plt.grid(False)
        plt.imshow(train_images[i], cmap=plt.cm.binary)
        plt.xlabel(class_names[train_labels[i]])
    plt.show()

# display25Images(train_images,train_labels,class_names)

def buildAndCompileModel():
    model = keras.Sequential([
        keras.layers.Flatten(input_shape=(28, 28)),
        keras.layers.Dense(128, activation='relu'),
        keras.layers.Dense(10, activation='softmax')
    ])
    model.compile(optimizer='adam', 
              loss='sparse_categorical_crossentropy',
              metrics=['accuracy'])
    return model

def trainModel(model, train_images, train_labels):
    model.fit(train_images, train_labels, epochs=5)    

def evaluateAccuracy(model, test_images, test_labels):
    return model.evaluate(test_images, test_labels)    

model = buildAndCompileModel()
trainModel(model, train_images, train_labels)
test_loss, test_acc = evaluateAccuracy(model, test_images, test_labels)

# get hold of the current run
run = Run.get_context()
run.log('Accuracy', np.float(test_acc))
print('\nTest accuracy:', test_acc)

model.save('outputs/fmnist.h5')