#!/bin/bash

#
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

##################################################
# Build and run TensorFlow Transferred Learning model. This is based on:
# https://github.com/tensorflow/models/blob/master/research/object_detection/g3doc/running_pets.md
# Also see this tutorial: https://cloud.google.com/solutions/creating-object-detection-application-tensorflow
##################################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

source ./setenv.sh

##################################################
# Generate JSON file with list of IDs and labels
# Inputs:
#   - full path and file name for the pbtxt file to be generated
##################################################
generate_pbtxt_file() {
  local PBTXT_FILE=$1
  echo_my "generate_pbtxt_file(): PBTXT_FILE=$PBTXT_FILE..."

cat << EOF > $PBTXT_FILE
item {
  id: $BLUE_BALL_ID
  name: '$BLUE_BALL_LABEL'
}
item {
  id: $RED_BALL_ID
  name: '$RED_BALL_LABEL'
}
item {
  id: $YELLOW_BALL_ID
  name: '$YELLOW_BALL_LABEL'
}
item {
  id: $GREEN_BALL_ID
  name: '$GREEN_BALL_LABEL'
}
item {
  id: $YELLOW_HOME_ID
  name: '$YELLOW_HOME_LABEL'
}
item {
  id: $RED_HOME_ID
  name: '$RED_HOME_LABEL'
}
item {
  id: $BLUE_HOME_ID
  name: '$BLUE_HOME_LABEL'
}
item {
  id: $GREEN_HOME_ID
  name: '$GREEN_HOME_LABEL'
}
EOF
}

##################################################
# Generate map of files to ids in the current folder
# Files to be generated: list.txt, trainval.txt, test.txt
# Note that list is a concatenation of the other two
##################################################
generate_id_map_file() {
  echo_my "generate_id_map_file()..."
  local TRAINING_VALUES="trainval.txt"
  touch ${TRAINING_VALUES}

  cd xmls
  for file in *.xml
  do
      local NAME=$(echo $file | sed -n -e "s/.xml//p")
      local KIND=1
      local TYPE=1
      local CLASS=undefined
      # truncate everything starting with '_*' - just keep the color
      local CLASS_STRING=$(echo $file | sed -n -e "s/_.*$//p")
      # convert to lower case
      CLASS_STRING=$(echo $CLASS_STRING | sed -e 's/\(.*\)/\L\1/')
      case $CLASS_STRING in
          blueball)
            CLASS=$BLUE_BALL_ID
            ;;
          redball)
            CLASS=$RED_BALL_ID
            ;;
          yellowball)
            CLASS=$YELLOW_BALL_ID
            ;;
          greenball)
            CLASS=$GREEN_BALL_ID
            ;;
          bluehome)
            CLASS=$BLUE_HOME_ID
            ;;
          redhome)
            CLASS=$RED_HOME_ID
            ;;
          yellowhome)
            CLASS=$YELLOW_HOME_ID
            ;;
          greenhome)
            CLASS=$GREEN_HOME_ID
            ;;
          *)
            echo_my "Found an unknown type of file: '$file'" $ECHO_ERROR
            # skip writing this file into the list file
            continue
            ;;
      esac

      echo "$NAME $CLASS $KIND $TYPE" >> ../${TRAINING_VALUES}
  done

  # TODO - this code below may not be needed as it does not appear that any of these two files are being used

  # Split the file generated above into two files
#  cd ..
#  touch test.txt
#  touch trainval.txt
#
#  local flag=0
#  while IFS='' read -r line || [[ -n "$line" ]]; do
#      if ((flag)) # every other line goes into a separate file
#      then
#          echo "$line" >> test.txt
#      else
#          echo "$line" >> trainval.txt
#      fi
#      flag=$((1-flag))
#  done < "list.txt"
}

##################################################
# Prepare Object Detection API
##################################################
setup_object_detection() {
  echo_my "Setting up Tensor Flow Object Detection API for training..."

  # Prepare images and annotations
  LOCAL_TMP=$TMP/object_detection
  rm -rf $LOCAL_TMP
  mkdir -p $LOCAL_TMP
  cd $LOCAL_TMP
  local CWD=$(pwd)

  IMAGES_ZIP=images-for-training.zip
  ANNOTATIONS_ZIP=annotations.zip

  echo_my "Download training images..."
  gsutil cp gs://$GCS_IMAGES/$IMAGES_ZIP ./

  echo_my "Download annotations..."
  gsutil cp gs://$GCS_IMAGES/$ANNOTATIONS_ZIP ./
  mkdir -p annotations/xmls
  mkdir -p images

  echo_my "Extract all into flat directory and ignore subdirectories"
  unzip -q -j $ANNOTATIONS_ZIP -d annotations/xmls
  unzip -q -j $IMAGES_ZIP -d images

  echo_my "Free up space since we dont need zip files anymore"
  rm -rf $ANNOTATIONS_ZIP
  rm -rf $IMAGES_ZIP

  cd $CWD/annotations
  generate_id_map_file

  cd $CWD
  local LABEL_MAP_FILE=$(pwd)/annotations/cloud_derby_label_map.pbtxt
  generate_pbtxt_file $LABEL_MAP_FILE

  echo_my "Convert training data to TFRecords..."
  cd $CWD
  python ${MODEL_CONFIG_PATH}/python/create_cloud_derby_tf_record.py \
      --label_map_path=$LABEL_MAP_FILE \
      --data_dir=$CWD \
      --output_dir=$CWD

  echo_my "Removing existing objects and bucket '$GCS_ML_BUCKET' from GCS..."
  gsutil -m rm -r $GCS_ML_BUCKET/* | true
  gsutil rb $GCS_ML_BUCKET | true # ignore the error if bucket does not exist

  echo_my "Upload dataset to GCS..."
  gsutil mb -l $REGION -c regional $GCS_ML_BUCKET
  gsutil cp cloud_derby_train.record $GCS_ML_BUCKET/data/cloud_derby_train.record
  gsutil cp cloud_derby_val.record $GCS_ML_BUCKET/data/cloud_derby_val.record
  gsutil cp $LABEL_MAP_FILE $GCS_ML_BUCKET/data/cloud_derby_label_map.pbtxt

  echo_my "Upload pretrained COCO Model for Transfer Learning..."
  wget https://storage.googleapis.com/download.tensorflow.org/models/object_detection/${MODEL}.tar.gz
  tar -xf ${MODEL}.tar.gz
  gsutil cp $MODEL/model.ckpt.* $GCS_ML_BUCKET/data/
  rm -rf ${MODEL}.tar.gz

  gsutil cp $MODEL_CONFIG_PATH/$MODEL_CONFIG \
  $GCS_ML_BUCKET/data/$MODEL_CONFIG

  echo_my "Packaging the TensorFlow Object Detection API and TF Slim..."
  cd $TF_MODEL_DIR/models/research
  python setup.py sdist
  (cd slim && python setup.py sdist)
}

##################################################
# Generate CLOUD.YML file
# Inputs:
#   - file to be generated
##################################################
generate_cloud_yml_file() {
  local YML_FILE=$1
  echo_my "generate_cloud_yml_file(): YML_FILE=$YML_FILE..."

cat << EOF > $YML_FILE
# Please do not edit this file by hand - it is auto-generated by script
# See details here: https://cloud.google.com/ml-engine/docs/training-overview
# masterType: complex_model_m_p100
# workerType: complex_model_m_p100

trainingInput:
  scaleTier: CUSTOM
  masterType: standard_gpu
  workerCount: 1
  workerType: standard_gpu
  parameterServerCount: 1
  parameterServerType: standard
EOF
}

#############################################
# Generate Model Config file for
# Consider this material: http://www.frank-dieterle.de/phd/2_8_1.html
#############################################
generate_model_config_faster_rcnn_resnet101() {
  local MODEL_CONFIG=$1
  echo_my "generate_model_config_faster_rcnn_resnet101(): MODEL_CONFIG=$MODEL_CONFIG..."

cat << EOF > $MODEL_CONFIG
# Faster R-CNN with Resnet-101 (v1) configured for the Oxford-IIIT Pet Dataset.
# Users should configure the fine_tune_checkpoint: "${GCS_ML_BUCKET}/data/model.ckpt"
# well as the label_map_path and input_path fields in the train_input_reader and
# eval_input_reader. Search for "${GCS_ML_BUCKET}/data" to find the fields that
# should be configured.
model {
  faster_rcnn {
    num_classes: ${NUM_CLASSES}
    image_resizer {
      keep_aspect_ratio_resizer {
        min_dimension: 600
        max_dimension: ${HORIZONTAL_RESOLUTION_PIXELS}
      }
    }
    feature_extractor {
      type: 'faster_rcnn_resnet101'
      first_stage_features_stride: 16
    }
    first_stage_anchor_generator {
      grid_anchor_generator {
        scales: [0.25, 0.5, 1.0, 2.0]
        aspect_ratios: [0.5, 1.0, 2.0]
        height_stride: 16
        width_stride: 16
      }
    }
    first_stage_box_predictor_conv_hyperparams {
      op: CONV
      regularizer {
        l2_regularizer {
          weight: 0.0
        }
      }
      initializer {
        truncated_normal_initializer {
          stddev: 0.01
        }
      }
    }
    first_stage_nms_score_threshold: 0.0
    first_stage_nms_iou_threshold: 0.7
    first_stage_max_proposals: ${first_stage_max_proposals}
    first_stage_localization_loss_weight: 2.0
    first_stage_objectness_loss_weight: 1.0
    initial_crop_size: 14
    maxpool_kernel_size: 2
    maxpool_stride: 2
    second_stage_box_predictor {
      mask_rcnn_box_predictor {
        use_dropout: false
        dropout_keep_probability: 1.0
        fc_hyperparams {
          op: FC
          regularizer {
            l2_regularizer {
              weight: 0.0
            }
          }
          initializer {
            variance_scaling_initializer {
              factor: 1.0
              uniform: true
              mode: FAN_AVG
            }
          }
        }
      }
    }
    second_stage_post_processing {
      batch_non_max_suppression {
        score_threshold: ${score_threshold}
        iou_threshold: 0.6
        max_detections_per_class: ${max_detections_per_class}
        max_total_detections: ${max_total_detections}
      }
      score_converter: SOFTMAX
    }
    second_stage_localization_loss_weight: 2.0
    second_stage_classification_loss_weight: 1.0
  }
}
train_config: {
  batch_size: 1
  optimizer {
    momentum_optimizer: {
      learning_rate: {
        manual_step_learning_rate {
          initial_learning_rate: 0.0003
          schedule {
            step: 900000
            learning_rate: .00003
          }
          schedule {
            step: 1200000
            learning_rate: .000003
          }
        }
      }
      momentum_optimizer_value: 0.9
    }
    use_moving_average: false
  }
  gradient_clipping_by_norm: 10.0
  fine_tune_checkpoint: "${GCS_ML_BUCKET}/data/model.ckpt"
  from_detection_checkpoint: true

  # Note: The below line limits the training process to $TRAINING_STEPS number of steps, which we
  # empirically found to be sufficient enough to train our dataset. This
  # effectively bypasses the learning rate schedule (the learning rate will
  # never decay). Remove the below line to train indefinitely.

  num_steps: ${TRAINING_STEPS}

  # More info about different augmentation options: https://stackoverflow.com/questions/44906317/what-are-possible-values-for-data-augmentation-options-in-the-tensorflow-object
  data_augmentation_options {
    random_horizontal_flip {
    }
    random_image_scale {
    }
    random_adjust_brightness {
    }
    random_adjust_contrast {
    }
    random_pad_image {
    }
    random_crop_image {
    }
  }
}
train_input_reader: {
  tf_record_input_reader {
    input_path: "${GCS_ML_BUCKET}/data/cloud_derby_train.record"
  }
  label_map_path: "${GCS_ML_BUCKET}/data/cloud_derby_label_map.pbtxt"
}
eval_config: {
  num_examples: 2000
  # Note: The below line limits the evaluation process to 10 evaluations.
  # Remove the below line to evaluate indefinitely.
  max_evals: 10
}
eval_input_reader: {
  tf_record_input_reader {
    input_path: "${GCS_ML_BUCKET}/data/cloud_derby_val.record"
  }
  label_map_path: "${GCS_ML_BUCKET}/data/cloud_derby_label_map.pbtxt"
  shuffle: false
  num_readers: 1
}
EOF
}

##################################################
# Start TF training
##################################################
train_model() {
  echo_my "train_model(): TF version $(python -c 'import tensorflow as tf; print(tf.__version__)')"
  cd $CWD

  if ( $LOCAL_TRAINING ); then
    echo_my "Start LOCAL training job..."
    rm nohup.out | true # ignore error

    nohup gcloud ml-engine local train \
    --job-dir=$GCS_ML_BUCKET/train \
    --package-path $TF_MODEL_DIR/models/research/object_detection \
    --module-name object_detection.legacy.train \
    -- \
    --train_dir=$GCS_ML_BUCKET/train \
    --pipeline_config_path=$GCS_ML_BUCKET/data/$MODEL_CONFIG &

    # Wait few seconds before showing output
    sleep 5
    tail -f nohup.out

  else
    echo_my "Start REMOTE training job..."
    YML=$TMP/cloud.yml
    generate_cloud_yml_file $YML
    # See details here: https://cloud.google.com/ml-engine/docs/training-overview

    gcloud ml-engine jobs submit training $(whoami)_object_detection_$(date +%s) \
      --job-dir=$GCS_ML_BUCKET/train \
      --packages $TF_MODEL_DIR/models/research/dist/object_detection-0.1.tar.gz,$TF_MODEL_DIR/models/research/slim/dist/slim-0.1.tar.gz,/tmp/pycocotools/pycocotools-2.0.tar.gz \
      --module-name object_detection.legacy.train \
      --region $REGION \
      --runtime-version $CMLE_RUNTIME_VERSION \
      --config $YML \
      -- \
      --train_dir=$GCS_ML_BUCKET/train \
      --pipeline_config_path=$GCS_ML_BUCKET/data/$MODEL_CONFIG

    echo_my "Start evaluation job concurrently with training..."

    gcloud ml-engine jobs submit training $(whoami)_object_detection_eval_$(date +%s) \
      --job-dir=$GCS_ML_BUCKET/train \
      --packages $TF_MODEL_DIR/models/research/dist/object_detection-0.1.tar.gz,$TF_MODEL_DIR/models/research/slim/dist/slim-0.1.tar.gz,/tmp/pycocotools/pycocotools-2.0.tar.gz \
      --module-name object_detection.legacy.train \
      --runtime-version $CMLE_RUNTIME_VERSION \
      --region $REGION \
      --scale-tier BASIC_GPU \
      -- \
      --checkpoint_dir=$GCS_ML_BUCKET/train \
      --eval_dir=$GCS_ML_BUCKET/eval \
      --pipeline_config_path=$GCS_ML_BUCKET/data/$MODEL_CONFIG

      echo_my "Now check the ML dashboard: https://console.cloud.google.com/mlengine/jobs."
      echo_my "It may take up to 3 hours to complete the training job."
      echo_my "Go to the [GCP Console]->[GCE]->[VMs]->[tensorboard-dev]."
      echo_my "SSH into this VM and run tensorboard.sh script.\n"
  fi
}

##################################################
# Configuring TF research models
# Based on this tutorial: https://cloud.google.com/solutions/creating-object-detection-application-tensorflow
##################################################
setup_models() {
    echo_my "Setting up Proto and TensorFlow Models..."

	if [ -d "$TF_MODEL_DIR" ]; then
	    rm -rf $TF_MODEL_DIR
	fi
	mkdir -p $TF_MODEL_DIR
	cd $TF_MODEL_DIR

  # Configure dev environment - pull down TF models
  git clone https://github.com/tensorflow/models.git
  cd models
  # object detection master branch has a bug as of 9/21/2018
  # checking out a commit we know works
  git reset --hard 256b8ae622355ab13a2815af326387ba545d8d60
  cd ..

  PROTO_V=3.3
  PROTO_SUFFIX=0-linux-x86_64.zip

	if [ -d "protoc_${PROTO_V}" ]; then
	    rm -rf protoc_${PROTO_V}
	fi

  mkdir protoc_${PROTO_V}
  cd protoc_${PROTO_V}

  echo_my "Download PROTOC..."
  wget https://github.com/google/protobuf/releases/download/v${PROTO_V}.0/protoc-${PROTO_V}.${PROTO_SUFFIX}
  chmod 775 protoc-${PROTO_V}.${PROTO_SUFFIX}
  unzip protoc-${PROTO_V}.${PROTO_SUFFIX}
  rm -rf protoc-${PROTO_V}.${PROTO_SUFFIX}

  echo_my "Compiling protos..."
  cd $TF_MODEL_DIR/models/research
  bash object_detection/dataset_tools/create_pycocotools_package.sh /tmp/pycocotools
  python setup.py sdist
  (cd slim && python setup.py sdist)

  PROTOC=$TF_MODEL_DIR/protoc_${PROTO_V}/bin/protoc
  $PROTOC object_detection/protos/*.proto --python_out=.
}

#############################################
# MAIN
#############################################
print_header "TensorFlow transferred learning training"

CWD=$(pwd)
TMP=$CWD/tmp
mkdir -p $TMP
INSTALL_FLAG=${TMP}/install.marker

if [ -f "$INSTALL_FLAG" ]; then
  echo_my "Marker file '$INSTALL_FLAG' was found = > no need to do the install."
else
  echo_my "Marker file '$INSTALL_FLAG' was NOT found = > starting one time install."
  # This is to allow NVIDIA packages to be verified
  curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
  yes | sudo apt-get update
  yes | sudo apt-get install apt-transport-https unzip zip
  setup_models
  touch $INSTALL_FLAG
fi

generate_model_config_faster_rcnn_resnet101 $MODEL_CONFIG_PATH/$MODEL_CONFIG
set_python_path
setup_object_detection
train_model

print_footer "Once the training is completed, run this script: export_tf_checkpoint.sh"