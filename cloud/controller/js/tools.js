/**
 * Copyright 2018, Google, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**************************************************************************
 Various useful things
 **************************************************************************/
const fs = require('fs');

/**************************************************************************
 Generates random whole number between 0 and MAX
 Params:
 - Max - upper bound
 Returns:
 - Random whole number
 **************************************************************************/
function randomWholeNum(max) {
  return Math.floor(Math.random() * max);
}

/**************************************************************************
 Converts degrees to radians
 Params:
 - Angle in Degrees
 Returns:
 - Angle in radians
 **************************************************************************/
function toRadians(angle) {
  return angle * (Math.PI / 180);
}

function toDegrees(angle) {
  return angle * (180 / Math.PI);
}

/**************************************************************************
 Returns YYYYMMDD format of the date
 Params:
 - date
 Returns:
 - time in format YYYYMMDD
 **************************************************************************/
function yyyymmdd(date) {
  Date.prototype.yyyymmdd = function () {
    const mm = this.getMonth() + 1; // getMonth() is zero-based
    const dd = this.getDate();
  
    return [this.getFullYear(), (mm > 9 ? '' : '0') + mm, (dd > 9 ? '' : '0') + dd].join('');
  };
  
  return new Date(date).yyyymmdd();
}

/**************************************************************************
 Returns YYYYMMDDHH format of the date
 Params:
 - date
 Returns:
 - time in format YYYYMMDDHH
 **************************************************************************/
function yyyymmddhh(date) {
  return yyyymmdd(date) + date.toUTCString().substr(17, 2);
}

/**************************************************************************
 Returns HHMMSS format of the date
 Params:
 - date
 Returns:
 - time in format HHMMSS
 **************************************************************************/
function hhmmss(date) {
  return date.toUTCString().substr(17, 8).replace(":", "").replace(":", "");
}

/**************************************************************************
 Generates random date between start and end
 Params:
 - Start date
 - End date
 Returns:
 - Random date between those two
 **************************************************************************/
function randomDate(start, end) {
  return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()));
}

/**************************************************************************
 Capitalizes first letter of the string, or second letter if string starts with
 quotation mark
 Params:
 - String to process
 Returns:
 - String with the first capital letter
 **************************************************************************/
function capitalizeFirstLetter(string) {
  if (string.charAt(0) == "\"") {
    return "\"" + string.charAt(1).toUpperCase() + string.slice(2);
  }
  return string.charAt(0).toUpperCase() + string.slice(1);
}

/**************************************************************************
 Get the size of the file in bytes
 Params:
 - Name of the file
 Returns:
 - Size in bytes
 **************************************************************************/
function getFilesizeInBytes(filename) {
  const stats = fs.statSync(filename);
  return stats["size"];
}

/**************************************************************************
 Convert millimiters to inches
 Params:
 - millimiters
 Returns:
 - inches
 **************************************************************************/
function mm2inches(mm) {
  return mm * 25.4;
}

/**************************************************************************
 Convert inches to millimiters
 Params:
 - inches
 Returns:
 - millimiters
 **************************************************************************/
function inches2mm(inches) {
  return inches / 25.4;
}

/**************************************************************************
 Export these functions so they can be used outside
 **************************************************************************/
module.exports = {
  randomWholeNum: randomWholeNum,
  toRadians: toRadians,
  toDegrees: toDegrees,
  mm2inches: mm2inches,
  inches2mm: inches2mm,
  yyyymmdd: yyyymmdd,
  yyyymmddhh: yyyymmddhh,
  hhmmss: hhmmss,
  randomDate: randomDate,
  capitalizeFirstLetter: capitalizeFirstLetter,
  getFilesizeInBytes: getFilesizeInBytes
};