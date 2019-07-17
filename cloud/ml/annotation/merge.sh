#!/bin/bash

######################################################################
# This script merges multiple user uploaded images into one archive
# Example:
#      ./merge.sh  USER-BUCKET-1  USER-BUCKET-2  USER-BUCKET-3  USER-BUCKET-4
#
# In the command below USER-BUCKET-X is the name of the bucket where each of
# the team members has uploaded their images:
######################################################################

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

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

source ../../../setenv-global.sh

# This is the name of the bucket with user provided annotated images
# It must have one or more zip files with the correct folder structure
# GCS_BUCKET=<...put unique GCS bucket name here - must match the name in upload.bat ...>
GCS_BUCKET="annotated-images-${PROJECT}-version-${VERSION}"

# As part of processing we will make sure that no file is larger than this resolution on any dimension
MAX_PIXELS="$HORIZONTAL_RESOLUTION_PIXELS"

# This is the name of the directory for all this temporary work
TMP="$(pwd)/tmp"

STOCK_FILE="provided-images"
STOCK_FOLDER="$TMP/$STOCK_FILE"
USER_FOLDER="$TMP/user_images"
NO_MATCH="$TMP/non-matching"

# How many files were found with invalid pixel sizes
LARGE_SIZE_FILES_COUNT=0

#############################################
# Download images and annotations provided by instructors
#############################################
download_stock_images() {
  echo_my "download_stock_images(): Copy object annotations and images from '$GCS_SOURCE_IMAGES' into '$STOCK_FOLDER'..."
  local ZIP=$STOCK_FILE.zip
  cd $TMP

  gsutil cp gs://$GCS_SOURCE_IMAGES/$ZIP ./

  unzip $ZIP -d $STOCK_FOLDER
}

###############################################
# Download images provided by users
###############################################
download_user_images()
{
  echo_my "download_user_images(): ..."
  mkdir -p $USER_FOLDER
  cd $USER_FOLDER

  if [ ! -z ${SKIP_MANUAL_IMAGE_ANNOTATION+x} ]; then
      echo "Skipping user content download because SKIP_MANUAL_IMAGE_ANNOTATION variable is not set"
      return
  fi
  
  gsutil cp gs://$GCS_BUCKET/* ./

  # if [ -z "$(ls -A $USER_FOLDER)" ]; then
  #     echo_my "No zip files were found or downloaded from the user GCS bucket '$GCS_BUCKET' - skipping to the next step" $ECHO_WARNING
  #     return
  # fi

  echo_my "Extract all user provided images into separate directories..."
  find . -name '*.zip' -exec sh -c 'unzip -d "${1%.*}" "$1"' _ {} \;
  rm *.zip
}

###############################################
# Upload merged images to the GCS bucket for training
###############################################
upload_for_training()
{
  echo_my "upload_for_training(): Create new GSC bucket '$GCS_IMAGES'..."
  gsutil mb gs://$GCS_IMAGES | true # ignore if it exists

  cd $STOCK_FOLDER

  zip -r annotations . -i \*.xml
  zip -r images-for-training . -i \*.jpg

  echo_my "upload_for_training(): Copy files to the bucket bucket '$GCS_IMAGES'..."
  gsutil cp ./*.zip gs://$GCS_IMAGES
  rm ./*.zip
}

###############################################
# Rename files in a given subfolder
# Input:
#   - folder name
###############################################
rename_files_in_folder()
{
  local CWD=$(pwd)
  local FOLDER=$1
  echo_my "rename_files_in_folder(): '${CWD}/$FOLDER'..."
  cd $FOLDER
  local TMP=temp
  mkdir -p $TMP
  # Remove spaces from directory names
  find . -name "* *" -type d | rename 's/ /_/g'
  # Remove spaces from file names
  find . -name "* *" -type f | rename 's/ /_/g'

  # Remove % from directory names
  find . -name "*%*" -type d | rename 's/%/_/g'
  # Remove spaces from file names
  find . -name "*%*" -type f | rename 's/%/_/g'

  echo_my "Make sure there are no XML files without the matching JPG file..."
  for file in *.xml
  do
      echo_my "rename_files_in_folder(): Processing file='$file'";
      # Remove .xml file extention
      FILE_BASE_NAME=$(echo $file | sed -n -e "s/.xml$//p")
      # Check if there is corresponding jpg file
      if ! ( stat -t ${FILE_BASE_NAME}.jpg > /dev/null 2>&1 ); then
          echo_my "File '$file' does not have a matching JPG file. Moving it to '$NO_MATCH'" $ECHO_WARNING
          mv $file $NO_MATCH | true # ignore if error
      fi
  done

  echo_my "Make sure there are no JPG files without the matching XML file..."
  for file in *.jpg
  do
      echo_my "rename_files_in_folder(): Processing file '$file'";
      # Remove file extention
      FILE_BASE_NAME=$(echo $file | sed -n -e "s/.jpg$//p")
      # Check if there is corresponding XML file
      if ! ( stat -t ${FILE_BASE_NAME}.xml > /dev/null 2>&1 ); then
          echo_my "File '$file' does not have a matching XML file. Moving it to '$NO_MATCH'" $ECHO_WARNING
          mv $file $NO_MATCH | true # ignore if error
      fi
  done

  # Find the maximum index of the file that already has proper name
  local MAX_NUM=0
  local VALID_FILES=0
  for file in ${FOLDER}_*.jpg
  do
      # Move the file into processed directory
      if ( stat -t $file > /dev/null 2>&1 ); then
          # https://unix.stackexchange.com/questions/24140/return-only-the-portion-of-a-line-after-a-matching-pattern?utm_medium=organic&utm_source=google_rich_qa&utm_campaign=google_rich_qa
          # Extract numeric portion of the file
          NUM=$(echo $file | sed -n -e "s/${FOLDER}_//p" | sed -n -e "s/.jpg$//p")
          # Check if this is an integer number
          re='^[0-9]+$'
          if [[ $NUM =~ $re ]] ; then
              echo_my "rename_files_in_folder(): Moving file '$file' to '$TMP'..."
              mv $file $TMP
              VALID_FILES=$(echo "$VALID_FILES + 1" | bc)
              if (( $MAX_NUM < $NUM )); then
                  MAX_NUM=$NUM
              fi
          fi
      fi
  done

  # Only rename files that do not match naming structure
  # All proper files have been moved to the subdirectory
  for file in *.jpg
  do
      # echo "Found non-conformant file='$file'";
      if ( stat -t $file > /dev/null 2>&1 ); then
          MAX_NUM=$(echo "$MAX_NUM + 1" | bc)
          echo_my "rename_files_in_folder(): Renaming file pair '$file'..."
          # While we are at it - rename the matching XML file
          local OLD_NAME=${file%.*}
          local NEW_NAME=${FOLDER}_${MAX_NUM}

          echo_my "Renaming '${OLD_NAME}.xml' into '${NEW_NAME}.xml'"
          mv ${OLD_NAME}.xml ${NEW_NAME}.xml

          echo_my "Renaming reference inside of '$OLD_NAME' into file '$NEW_NAME'"
          # Rename the reference to the old JPG file name within XML file with new name
          local SEARCH="${OLD_NAME}.jpg"
          local REPLACE="${NEW_NAME}.jpg"
          sed -i -e 's/'$SEARCH'/'$REPLACE'/g' ${NEW_NAME}.xml

          echo_my "Move '$file' into '$TMP/${FOLDER}_${MAX_NUM}.jpg'"
          mv $file $TMP/${FOLDER}_${MAX_NUM}.jpg
      fi
  done

  echo_my "Move image files back to their original directory..."
  mv $TMP/* ./ | true # ignore if there are no files and nothing to move
  rm -rf $TMP

  cd $CWD
  echo_my "Processed folder '$FOLDER': found $VALID_FILES properly named images, processed $MAX_NUM files."
}

###############################################
# Update XML file that is in Pascal VOC format to change the bounding box and other things in the file.
# This is needed because we will resize the image file to a max pixel dimension and that will invalidate the XML coordinates
# Input:
#   - 1 - jpg file name
#   - 2 - max allowed pixel size (height and width)
#   - 3 - initial file width
#   - 4 - initial file height
#   - 5 - file width after resizing
#   - 6 - file height after resizing
#
# Example of the XML file to be processed:
# <annotation>
# 	<folder>BlueBall</folder>
# 	<filename>BlueBall_2.jpg</filename>
# 	<path>C:\Users\sasha\Google Drive\Machine Learning\images_renamed\BlueBall\BlueBall_2.jpg</path>
# 	<source>
# 		<database>Unknown</database>
# 	</source>
# 	<size>
# 		<width>468</width>
# 		<height>458</height>
# 		<depth>3</depth>
# 	</size>
# 	<segmented>0</segmented>
# 	<object>
# 		<name>ball</name>
# 		<pose>Unspecified</pose>
# 		<truncated>0</truncated>
# 		<difficult>0</difficult>
# 		<bndbox>
# 			<xmin>28</xmin>
# 			<ymin>24</ymin>
# 			<xmax>442</xmax>
# 			<ymax>420</ymax>
# 		</bndbox>
# 	</object>
# </annotation>
###############################################
convert_xml_pixels()
{
  # Make sure that no file is larger than this resolution on any dimension
  local IMG_FILE=$1
  local MAX_PIXELS=$2
  local WIDTH=$3
  local HEIGHT=$4
  local NEW_WIDTH=$5;
  local NEW_HEIGHT=$6;

  echo_my "convert_xml_pixels(): processing Pascal VOC XML file for '${IMG_FILE}' original size ${WIDTH}x${HEIGHT} to a new size ${NEW_WIDTH}x${NEW_HEIGHT}..."

  # Ratio of size conversion
  local RATIO=0;
  # Size of converted (reduced) file
  local NEW_XMIN=0;

  # Truncate eveything after the dot in file extension
  local XML_FILE=$(echo $IMG_FILE | sed -n -e "s/.jpg*$//p")
  XML_FILE=${XML_FILE}.xml
  local XML_STRING=$(cat $XML_FILE)
  # echo "String before: $XML_STRING"

  RATIO=$(echo "scale=5; $NEW_WIDTH / $WIDTH" | bc)

  # ------------------------------------- use -e command for the sed to add up many commands - https://unix.stackexchange.com/questions/33157/what-is-the-purpose-of-e-in-sed-command

  # Read values from XML
  local XMIN=$(echo "$XML_STRING" | perl -ne 'print "$1" if /<xmin>(.*?)<\/xmin>/')
  local YMIN=$(echo "$XML_STRING" | perl -ne 'print "$1" if /<ymin>(.*?)<\/ymin>/')
  local XMAX=$(echo "$XML_STRING" | perl -ne 'print "$1" if /<xmax>(.*?)<\/xmax>/')
  local YMAX=$(echo "$XML_STRING" | perl -ne 'print "$1" if /<ymax>(.*?)<\/ymax>/')

  # Calculate new values (no need to recalculate overall dimensions as they come in as parameters to this call)
  local NEW_XMIN=$(echo "scale=0; ($XMIN * $RATIO)/1" | bc)
  local NEW_XMAX=$(echo "scale=0; ($XMAX * $RATIO)/1" | bc)
  local NEW_YMIN=$(echo "scale=0; ($YMIN * $RATIO)/1" | bc)
  local NEW_YMAX=$(echo "scale=0; ($YMAX * $RATIO)/1" | bc)

  # echo_my "Coversion ratio is $RATIO, NEW_XMIN=$NEW_XMIN NEW_XMAX=$NEW_XMAX NEW_YMIN=$NEW_YMIN NEW_YMAX=$NEW_YMAX"

  # Replace values in XML
  XML_STRING=$(echo "$XML_STRING" | sed 's/<width>.*<\/width>/<width>'"$NEW_WIDTH"'<\/width>/' | sed 's/<height>.*<\/height>/<height>'"$NEW_HEIGHT"'<\/height>/')
  XML_STRING=$(echo "$XML_STRING" | sed 's/<xmin>.*<\/xmin>/<xmin>'"$NEW_XMIN"'<\/xmin>/' | sed 's/<ymin>.*<\/ymin>/<ymin>'"$NEW_YMIN"'<\/ymin>/')
  XML_STRING=$(echo "$XML_STRING" | sed 's/<xmax>.*<\/xmax>/<xmax>'"$NEW_XMAX"'<\/xmax>/' | sed 's/<ymax>.*<\/ymax>/<ymax>'"$NEW_YMAX"'<\/ymax>/')

  # Write values back into XML
  echo "$XML_STRING" > $XML_FILE

  echo_my "convert_xml_pixels(): processed file '$XML_FILE'."
}

###############################################
# Resize files in a given subfolder to conform to TensorFlow requirements
# As part of the jpg resizing we will also adjust XML annotations as to not break them
# Input:
#   - folder name
###############################################
resize_files()
{
    local CWD=$(pwd)
    local FOLDER=$1
    echo_my "resize_files(): processing folder '${CWD}/$FOLDER'..."
    cd $FOLDER
    local TMP=temp
    mkdir -p $TMP

    local FILES_COUNT=0

    for file in *.jpg
    do
        FILES_COUNT=$(echo "$FILES_COUNT + 1" | bc)
        # See Imagemagic docs on how to use it: https://guides.wp-bullet.com/batch-resize-images-using-linux-command-line-and-imagemagick/
        local RESOLUTION=$(identify -format "%wx%h" $file)
        # The result of the above is in the format of "3960x2120"
        # Remove everything after the "x" sign
        local HEIGHT=$(echo $RESOLUTION | sed -n -e "s/.*x//p")
        # Remove everything before the "x" sign
        local WIDTH=$(echo $RESOLUTION | sed -n -e "s/x.*$//p")
        echo_my "File $file height=$HEIGHT width=$WIDTH"

        if test "$HEIGHT" -gt "$MAX_PIXELS" || test "$WIDTH" -gt "$MAX_PIXELS" 
        then
            echo_my "Converting file '$file' with  w=$WIDTH H=$HEIGHT to a max allowed ${MAX_PIXELS}x${MAX_PIXELS} pixels" $ECHO_WARNING
            LARGE_SIZE_FILES_COUNT=$(echo "$LARGE_SIZE_FILES_COUNT + 1" | bc)
            # Resize the image using imagemagic tool
            convert $file -resize ${MAX_PIXELS}x${MAX_PIXELS}\> $file

            # Get new dimensions of the file after convesion
            RESOLUTION=$(identify -format "%wx%h" $file)
            local NEW_HEIGHT=$(echo $RESOLUTION | sed -n -e "s/.*x//p")
            local NEW_WIDTH=$(echo $RESOLUTION | sed -n -e "s/x.*$//p")

            # Update corresponding XML file to recalculate the coordinates of the bounding box
            convert_xml_pixels $file ${MAX_PIXELS} $WIDTH $HEIGHT $NEW_WIDTH $NEW_HEIGHT
        fi
    done

    cd $CWD
    echo_my "resize_files(): processed folder '$FOLDER' with $FILES_COUNT files."
}

###############################################
# Merge provided and user images into one
# Input:
#   1 - directory that needs to be merged
###############################################
merge_all_images()
{
  local FOLDER=$1
  echo_my "merge_all_images() from folder '$FOLDER'..."

  # We should only process directories
  if ! [ -d "$FOLDER" ] ; then
      echo_my "ERROR - '$FOLDER' this is not a directory - exiting." $ECHO_WARNING
      return
  fi

  if [ -z "$(ls -A $FOLDER)" ]; then
      echo_my "No files were found in the user folder '$FOLDER'" $ECHO_WARNING
      return
  fi

  # Iterate over all files
  for FILE in $FOLDER/*.jpg
  do
      # echo_my "Processing file '$FILE'..."
      if ! ( stat -t $FILE > /dev/null 2>&1 ); then
          continue
      fi

      # echo_my "Full file name: '$FILE', short name '${FILE##*/}'"
      # Check if there is file with similar name in stock image directory
      local XML_FILE=${FILE%.*}.xml
      local DEST_FILE=$STOCK_FOLDER/${FOLDER##*/}/${FILE##*/}
      if [ -f "$DEST_FILE" ] ; then
          # If file sizes are the same - treat this as identical files and remove the one in the user directory
          local SRC_SIZE=$(du -b $FILE | cut -f 1 )
          local DEST_SIZE=$(du -b $DEST_FILE | cut -f 1 )

          if [[ $SRC_SIZE -eq $DEST_SIZE ]] ; then
              echo_my "File size of source and destination is identical - removing user file '$FILE'"
              rm $FILE
              rm $XML_FILE | true # ignore if there was no matching XML anyway
          else
              echo_my "File size of source and destination are different - moving user file '$FILE' over with different file name"
              local NOW=$(date +%Y-%m-%d.%H:%M:%S)
              mv $XML_FILE $STOCK_FOLDER/${FOLDER##*/}/${FILE##*/}.$NOW.xml | true # ignore if error as there may be no matching XML file
              mv $FILE $STOCK_FOLDER/${FOLDER##*/}/${FILE##*/}.$NOW.jpg
          fi
      else
          if [ -f $XML_FILE ]; then
              echo_my "Matching files not found '$FILE' '$XML_FILE' - moving both to the folder '$STOCK_FOLDER/${FOLDER##*/}'"
              mv $XML_FILE $STOCK_FOLDER/${FOLDER##*/} | true # ignore if error as there may be no matching XML file
              mv $FILE $STOCK_FOLDER/${FOLDER##*/}
          else
              echo_my "File '$FILE' does not have a matching XML file - skipping it"
              mv $FILE $NO_MATCH
          fi
      fi
  done
}

###############################################
# MAIN
###############################################
print_header "Merging images and annotations from multiple users into a single archive"

if [ -d "$TMP" ] ; then
    rm -rf $TMP
fi
mkdir -p $TMP
mkdir -p $NO_MATCH

# We need image magic to convert file resolutions for jpg
yes | sudo apt-get install imagemagick
sudo apt-get install unzip zip | true # ignore if already installed

download_stock_images

download_user_images

echo_my "Iterating over directories in '$USER_FOLDER' to merge multiple directories into one '$STOCK_FOLDER'..."
for DIR in $USER_FOLDER/*
do
    for SUB_DIR in $DIR/*
    do
        merge_all_images $SUB_DIR
    done
done

echo_my "Iterating over '$STOCK_FOLDER' directory and rename files to confirm with naming convention..."
cd $STOCK_FOLDER
for dir in ./*/
do
    dir=${dir%*/}
    rename_files_in_folder ${dir##*/}
done

echo_my "Iterating over '$STOCK_FOLDER' directory and resize images to no larger than 1024x1024 as to not break TF training..."
cd $STOCK_FOLDER
for dir in ./*/
do
    dir=${dir%*/}
    resize_files ${dir##*/}
done
echo_my "Found and corrected $LARGE_SIZE_FILES_COUNT improperly sized images across all folders."

upload_for_training

print_footer "Merge has completed successfully."