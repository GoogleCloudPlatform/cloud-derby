/**
 * Copyright 2018, Google, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

'use strict';
console.log(`***Image sorting by score is starting up***`);

// Imports
const process = require('process'); // Required for mocking environment variables
const request = require('request');

const Storage = require('@google-cloud/storage');
const storage = new Storage(process.env.PROJECT);

const DESTINATION_BUCKET = process.env.DESTINATION_BUCKET;
const SOURCE_BUCKET = process.env.SOURCE_BUCKET;

// Global counter of processed files
let progressCount = 0;
let successCount = 0;

/************************************************************
 Process one file
 Input:
 - Source File name
 Output:
 - New file name
 ************************************************************/
function createNewName(fileName) {
  // Example input file name: 'count_10_high_7232_low_0522_file_4306.jpg'
  const keyword = '_low_';
  
  // If file name does not contain '_low_' keyword, then simply return the same name
  const keywordIndex = fileName.indexOf(keyword);
  if (keywordIndex < 0) {
    return fileName;
  }
  
  const keywordLength = keyword.length;
  const lowScoreFirstDigit = fileName[keywordIndex + keywordLength];
  const lastSlashPosition = fileName.lastIndexOf('/');
  return fileName.substring(0, lastSlashPosition + 1) + lowScoreFirstDigit + '/' + fileName.slice(lastSlashPosition + 1)
}

/************************************************************
 Copy file from one bucket into another
 Input:
 - source GCS URI
 - destination GCS URI
 ************************************************************/
async function gcsCopy(srcBucket, srcFile, destBucket, destFile) {
  // console.log('Copy from <gs://' + srcBucket + '/' + srcFile + '> to <gs://' + destBucket + '/' + destFile + '>');
  await storage.bucket(srcBucket).file(srcFile).copy(storage.bucket(destBucket).file(destFile))
  .catch(function (error) {
    console.error('!!!!!!!!!!!!! ERROR: Failed to copy a file: ' + destFile + ' with error: ' + error);
  });
}

/************************************************************
 Delete file from the bucket
 Input:
 - source GCS URI
 ************************************************************/
async function gcsDelete(bucket, file) {
  // console.log('Deleting file: '+file);
  storage.bucket(bucket).file(file).delete()
  .catch(function (error) {
    console.error("!!!!!!!!!!!! Failed to delete a file: " + error);
  });
}

/************************************************************
 Recursively process list of files
 Input:
 - List of files to be processed
 Output:
 - None
 ************************************************************/
async function processFilesAsync(files) {
  for (let file of files) {
    console.log('#' + progressCount);
    progressCount++;
    let newName = createNewName(file.name);
    
    // TODO - this needs to be async, but in batches so as to not overflow the memory for 80,000+ files
    await gcsCopy(SOURCE_BUCKET, file.name, DESTINATION_BUCKET, newName)
    .then(() => {
      gcsDelete(SOURCE_BUCKET, file.name);
      console.log('completed ' + successCount);
      // console.log('completed ' + successCount + ': ' + 'Copy from <gs://' + SOURCE_BUCKET + '/' + file.name + '> to'
      // + ' <gs://' + DESTINATION_BUCKET + '/' + newName + '>');
      successCount++;
    })
    .catch(function (error) {
      console.error('!!! Error processing file <' + file.name + '> with the error: ' + error);
    });
  }
}

/************************************************************
 MAIN
 ************************************************************/
console.log("Starting sorting by score...");

// let name = createNewName('BlueBall/count_10_high_7232_low_0522_file_4306.jpg');
// console.log('New name = ' + name);

let bucket = storage.bucket(SOURCE_BUCKET);

// bucket.getFiles({}, (err, files) => {console.log(err,files)});
bucket.getFiles({}, (err, files) => {
  if (err) {
    console.error('!!! ERROR listing of files in bucket <: ' + SOURCE_BUCKET + '>: ' + err);
  } else {
    console.log('Bucket <' + SOURCE_BUCKET + '> contains <' + files.length + '> files.');
    processFilesAsync(files).then(() => {
      console.log('# of files processed successfully: ' + successCount);
    })
  }
});