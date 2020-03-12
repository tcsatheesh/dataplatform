from __future__ import absolute_import, division, print_function

import os

import numpy as np
import matplotlib.pylab as plt

import tensorflow as tf
from tensorflow import keras
import tensorflow_hub as hub
from tensorflow.keras import layers
import tensorflow.keras.backend as K

from azureml.core import Run

def getcwd():
    currentFile = __file__
    realPath = os.path.realpath(currentFile)
    dirPath = os.path.dirname(realPath)
    print ("Current working directory         : {0}".format(dirPath))
    return dirPath

parser = argparse.ArgumentParser()
parser.add_argument('--data-folder', type=str, dest='data_folder', help='data folder mounting point')
parser.add_argument('--modelFilePath', type=str, dest='output_filepath', default="outputs/model.pb", help='model output folder')
args = parser.parse_args()

data_folder = args.data_folder
output_filepath = args.output_filepath

data_root = os.path.join(data_folder, "flower_photos")
print ("data_root: {0}".format(data_root))


run = Run.get_context()

feature_extractor_url = "https://tfhub.dev/google/imagenet/resnet_v2_152/feature_vector/1"

def feature_extractor(x):
  feature_extractor_module = hub.Module(feature_extractor_url)
  return feature_extractor_module(x)

IMAGE_SIZE = hub.get_expected_image_size(hub.Module(feature_extractor_url))

image_generator = tf.keras.preprocessing.image.ImageDataGenerator(rescale=1/255)

image_data = image_generator.flow_from_directory(str(data_root), target_size=IMAGE_SIZE)
for image_batch,label_batch in image_data:
  print("Image batch shape: ", image_batch.shape)
  print("Labe batch shape: ", label_batch.shape)
  break

features_extractor_layer = layers.Lambda(feature_extractor, input_shape=IMAGE_SIZE+[3])

features_extractor_layer.trainable = False
model = tf.keras.Sequential([
  features_extractor_layer,
  layers.Dense(image_data.num_classes, activation='softmax')
])
model.summary()

sess = K.get_session()
init = tf.global_variables_initializer()
sess.run(init)

result = model.predict(image_batch)
print ("result.shape: {0}".format(result.shape))

model.compile(
  optimizer=tf.train.AdamOptimizer(), 
  loss='categorical_crossentropy',
  metrics=['accuracy'])

class CollectBatchStats(tf.keras.callbacks.Callback):
  def __init__(self):
    self.batch_losses = []
    self.batch_acc = []
    
  def on_batch_end(self, batch, logs=None):
    self.batch_losses.append(logs['loss'])
    self.batch_acc.append(logs['acc'])

steps_per_epoch = image_data.samples//image_data.batch_size
batch_stats = CollectBatchStats()
numberOfEpochs = 2
model.fit((item for item in image_data), epochs=numberOfEpochs, 
                    steps_per_epoch=steps_per_epoch,
                    callbacks = [batch_stats])

def getLogValues(logValues):
  vals = []
  for idx, val in enumerate(logValues):
    if (idx % (numberOfEpochs * 2) == 0):
      vals.append(val)
  return vals

#TODO: there is an issue in logging all the values. We hit some limit and the experiment throws and error
run.log_list(name="Losses",value=getLogValues(batch_stats.batch_losses))
run.log_list(name="Accuracy",value=getLogValues(batch_stats.batch_acc))

plt.figure()
plt.ylabel("Loss")
plt.xlabel("Training Steps")
plt.ylim([0,2])
plt.plot(batch_stats.batch_losses)
plt.savefig("outputs/fig1.png")

plt.figure()
plt.ylabel("Accuracy")
plt.xlabel("Training Steps")
plt.ylim([0,1])
plt.plot(batch_stats.batch_acc)

#plt.show()
plt.savefig("outputs/fig2.png")

label_names = sorted(image_data.class_indices.items(), key=lambda pair:pair[1])
label_names = np.array([key.title() for key, value in label_names])
print ("label_names:{0}".format(label_names))

result_batch = model.predict(image_batch)

labels_batch = label_names[np.argmax(result_batch, axis=-1)]
print ("labels_batch:{0}".format(labels_batch))

plt.figure(figsize=(10,9))
for n in range(30):
  plt.subplot(6,5,n+1)
  plt.imshow(image_batch[n])
  plt.title(labels_batch[n])
  plt.axis('off')
_ = plt.suptitle("Model predictions")
plt.savefig("outputs/fig3.png")


export_path = tf.contrib.saved_model.save_keras_model(model, output_filepath)
print ("export_path:{0}".format(export_path))

