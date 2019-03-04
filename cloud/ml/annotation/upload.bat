::
::  Copyright 2018 Google LLC
::
::  Licensed under the Apache License, Version 2.0 (the "License");
::  you may not use this file except in compliance with the License.
::  You may obtain a copy of the License at
::
::      https://www.apache.org/licenses/LICENSE-2.0
::
::  Unless required by applicable law or agreed to in writing, software
::  distributed under the License is distributed on an "AS IS" BASIS,
::  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
::  See the License for the specific language governing permissions and
::  limitations under the License.
::

:: --------------------------------------------------------------------
:: This script uploads user created annotations into GCS for future merge
:: with images from other users.
:: --------------------------------------------------------------------

:: Put unique GCS bucket name here - must be the same for all team members
set GCS_BUCKET=annotated-images-<PROJECT>-version-<VERSION>

:: Put file name here - different for each team member - DO NOT include "zip" extention in the name...
set ZIP_FILE=userXXX

cd C:\a-robot-images

:: --- Create archive with user provided annotations and images
"c:\Program Files\7-Zip\7z.exe" a -tzip -r %ZIP_FILE% *.xml *.jpg

:: --- Upload annotations and images to GCS for transferred learning
call gsutil cp %ZIP_FILE%.zip gs://%GCS_BUCKET%

del %ZIP_FILE%.zip

cd C:\cloud-derby\cloud\ml\annotation