#!/bin/bash -e

#
# Check that required variables are provided
#
# Note that we are deliberately using file mounts here, instead of environment variable mounts
# as these do get updated by Kubernetes. Doing so allows us to rotate the secret without needing
# to worry about restarting this pod.
#
[ -f /config/AWS_ACCESS_KEY_ID ] || (echo "AWS_ACCESS_KEY_ID must be provided"; exit 1)
[ -f /config/AWS_SECRET_ACCESS_KEY ] || (echo "AWS_SECRET_ACCESS_KEY must be provided"; exit 1)
[ -f /config/AWS_DEFAULT_REGION ] || (echo "AWS_DEFAULT_REGION must be provided"; exit 1)
[ -f /config/NAMESPACES ] || (echo "NAMESPACES must be provided"; exit 1)
[ -f /config/SECRET_NAME ] || (echo "SECRET_NAME must be provided"; exit 1)

while true
do
  # Re-fetch values on each iteration, in case they have changed
  export AWS_ACCESS_KEY_ID=$(cat /config/AWS_ACCESS_KEY_ID)
  export AWS_SECRET_ACCESS_KEY=$(cat /config/AWS_SECRET_ACCESS_KEY)
  export AWS_DEFAULT_REGION=$(cat /config/AWS_DEFAULT_REGION)
  NAMESPACES=$(cat /config/NAMESPACES)
  SECRET_NAME=$(cat /config/SECRET_NAME)

  echo
  date
  echo "Obtaining docker login from AWS"
  read __ __ __ USERNAME __ PASSWORD REGISTRY < <(aws ecr get-login --no-include-email)

  echo "Creating secret and applying"
  (
    for namespace in ${NAMESPACES}
    do
      echo "---"
      kubectl create secret \
        docker-registry ${SECRET_NAME} \
        --docker-server="${REGISTRY}" \
        --docker-username="${USERNAME}" \
        --docker-password="${PASSWORD}" \
        --dry-run=client \
        -o yaml \
        -n ${namespace}
    done
  ) | kubectl apply -f -

  echo "Sleeping 11.5 hours"
  sleep 41400
done
