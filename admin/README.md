Cloud Derby Setup
=====

Scripts in the `admin` folder are used to setup and run Cloud Derby event in your 
own GCP organization or inside of the cloudderby.io.

## Create new environment to run a public hackathon

The event settings can be updated in the [setenv.sh](setenv.sh) file:

- `NUM_TEAMS` - How many teams will participate in the workshop (between 1 and N).
- `NUM_PEOPLE_PER_TEAM` - How many people per team (usually between 1 and 6).
- `EVENT_NAME` - Name of the event (this is added to user and group names, so keep it short, such as "PIT", or "DC").
- `TOP_FOLDER` - Folder that holds all project sub-folders for users (use date of the event, such as "March-11-$EVENT_NAME").
- `DOMAIN` - Domain name (the org name - whatever your org name is, such as "cloudderby.io", or "acme.com").

In order to host Cloud Derby hackathon as a public event you need to run a hackathon setup script [create-hackathon.sh](create-hackathon.sh), which will do the following:

- Generate user accounts and associated groups for teams.
- Generate event folder and sub-folders for each team in the IAM structure.
- Grant permissions to teams to their own folders.
- Add groups to proper IAM policies to allow access to source repository and GCS bucket with annotated images.

In order to run the script, you need to have GCloud SDK installed in Debian or Ubuntu bash command line and run the following:

- `gcloud init` - this will initialize your admin credentials for the GCP Org.
- `./create-hackathon.sh` - this will create the environment for you.

After the completion of the script, you will have all users, groups and folders in the IAM structure and a file called users.csv in the `$HOME/cloud-derby/admin/tmp` subfolder.

## Collect user images after the hackathon

During the hackathon your users will be taking photos and running robots around the room with cameras. This creates a
great number of new images that can be used in subsequent training in future events to enhance model accuracy. In order
to capture those user images you can use [collect-images.sh](collect-images.sh) script. This script will scan all user 
created folders, projects and buckets and collect all images into a single bucket under the "Administration" project.

In order to use those images, human being needs to:
- Download those images from one buckets
- Remove repetitive images
- Organize images in a proper structure (see ["Annotation"](https://bit.ly/robotderby) section of the tutorial)
- Annotate said images
- Run training and check model accuracy against the previous model (same steps as in "ML Training" part of the tutorial)
- If the step above improves the accuracy, then merge annotated images with the base set 
- Remove collected images from the central bucket to prepare for future events

## Cleanup after the hackathon

After you host the event for your audience, you want to make sure that all users and groups are promptly removed from the IAM and all resources (VMs, buckets and projects) 
are deleted to avoid unncecessary charges. This cleanup process is fully automated. Here is what you need to do from the bash command line in your Debian or Ubuntu:

- `gcloud init` - this will initialize your admin credentials for the GCP Org.
- Verify that the settings in [setenv.sh](setenv.sh) match your environment (aka name of the event, number
 of teams and users).
- `./delete-hackathon.sh $FOLDER_ID` - this will erase users, groups, all folders, VMs, projects, etc. under the `$FOLDER_ID` the folder you created while generating new hackathon event.
for the event (for example "March-11-Denver" mapped into folder ID "123456789").
- If you do not want to remove users, groups and projects, you can run a script `./stop-vms.sh $FOLDER_ID` to stop all of the VMs in all nested sub-folders and projects under `$FOLDER_ID`.
