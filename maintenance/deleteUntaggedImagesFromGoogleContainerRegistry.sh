#!/bin/bash

#
# This script can be used to delete untagged images (or digests actually) from a Google Container Registry
#
# When re-using a tag for subsequent pushes there will be digests without a tag (because the tag will point to the latest build/digest)
# these digest can be removed in order to save space
#
# Please note that this script depends on jq (as well as tr)
#
# Author: https://github.com/rlindooren
#

# TODO: configure this yourself
REPOSITORY=eu.gcr.io/xxxxxxxx

# Get all images in repository
IMAGES=`gcloud container images list --repository=${REPOSITORY} --format=json | jq -r '.[].name' | tr '\r\n' ' '`
echo "Found these images: ${IMAGES}"
for IMAGE in ${IMAGES}
do
  echo "Processing image: ${IMAGE}"
  DIGESTS=`gcloud container images list-tags ${IMAGE} --format=json | jq -r '.[] | select(.tags | length == 0) | .digest' | tr '\r\n' ' '`
  echo "Found untagged digests: ${DIGESTS}"
  for DIGEST in ${DIGESTS}
  do
    echo "Deleting digest: ${DIGEST}"
    gcloud container images delete --quiet ${IMAGE}@${DIGEST}
  done
  echo ""
done
