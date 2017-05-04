#!/bin/bash

#
# Delete al un-used layers for images from a private Docker registry (that's started with docker-compose)
#
# This script:
# - should be started from the directory where the docker-compose.yaml file resides
# - depends on curl and jq (as well as grep, sed and tr)
# - is not optimized and only tested against a registry with version v2.6.1
# - (!) should run only when the Docker registry isn't busy with pulling/pushing images
#
# Additional notes:
# - the registry should allow the deletion of data (environment variable: REGISTRY_STORAGE_DELETE_ENABLED=true)
#
# Author: https://github.com/rlindooren
#

# TODO: configure these yourself
USER=XXXXX
PASS=XXXXX

HOST=https://localhost:5000

IMAGES=`curl -k -s -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' -u "$USER:$PASS" "$HOST/v2/_catalog" | jq -r '.repositories | @csv'  | sed -e 's/"//g' | sed -e 's/,/ /g'`
echo "Found images: $IMAGES"

for IMAGE in $IMAGES
do

  echo "Processing image: $IMAGE"

  # Get all tags for image
  TAGS=`curl -k -s -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' -u "$USER:$PASS" "$HOST/v2/$IMAGE/tags/list" | tr -d '\r' | jq -r '.tags | @csv' | sed -e 's/"//g' | sed -e 's/,/ /g'`
  echo "Found tags: $TAGS for image: $IMAGE"

  SHAS_TO_KEEP=""
  for TAG in $TAGS
  do
    echo "Getting latest manifest for tag: $TAG of image: $IMAGE"
    SHA=`curl -k -s -i -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' -u "$USER:$PASS" "$HOST/v2/$IMAGE/manifests/$TAG" | tr -d '\r' | grep 'Docker-Content-Digest: sha256:' | sed -e 's/Docker-Content-Digest: \(.*\)$/\1/g'`
    echo "Found SHA: $SHA"
    SHAS_TO_KEEP="$SHA $SHAS_TO_KEEP"
  done

  echo "Keeping these: $SHAS_TO_KEEP"

  # Get all marked manifests using the garbage collector
  SHAS_MARKED=`docker-compose exec registry /bin/registry garbage-collect --dry-run /etc/docker/registry/config.yml | grep "$IMAGE: marking manifest" | sed -e 's/.*marking manifest \(.*\)$/\1/g' | tr -d '\r'`

  for MARKED_SHA in $SHAS_MARKED
  do
    if [[ "$SHAS_TO_KEEP" == *$MARKED_SHA* ]]; then
      echo "$MARKED_SHA will NOT be deleted! (it's the latest for a tag)"
    else
      echo "$MARKED_SHA will be deleted"
      curl -k -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' -X DELETE -u "$USER:$PASS" "$HOST/v2/$IMAGE/manifests/$MARKED_SHA"
    fi
  done

done

echo "Running garbage collection"
docker-compose exec registry /bin/registry garbage-collect /etc/docker/registry/config.yml
