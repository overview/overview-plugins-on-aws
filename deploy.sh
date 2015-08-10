#!/bin/bash
#
# Usage: see README.md

set -e

DIR="$(dirname "$0")"
CLUSTER=plugins
LOAD_BALANCER_NAME=plugins
CONTAINER_ROLE=ecsServiceRole

mkdir -p "$DIR"/ecs-tasks

# Returns true iff service is defined
is_service_defined() {
  NAME=$1

  aws ecs list-services \
    --cluster "$CLUSTER" \
    | grep -c "service/$NAME\"" \
    >/dev/null
}

# Updates the task if it exists; creates it if it doesn't.
create_or_update_task_definition() {
  PORT=$1
  NAME=$2
  MEMORY_LIMIT=$3
  JSON_PATH="$DIR/ecs-tasks/$NAME.json"

  cat > "$JSON_PATH" <<EOS
    {
      "family": "$NAME",
      "containerDefinitions": [ {
        "name": "$NAME",
        "image": "overview/$NAME",
        "memory": $MEMORY_LIMIT,
        "portMappings": [ {
          "containerPort": 3000,
          "hostPort": $PORT
        } ]
      } ]
    }
EOS

  aws ecs register-task-definition \
    --cli-input-json file://"$JSON_PATH" \
    >/dev/null
}

# Ensures there's an Elastic Load Balancer [
add_elb_listener() {
  PORT=$1

  SSL_CERTIFICATE_ID=$(aws elb describe-load-balancers \
    --load-balancer-name="$LOAD_BALANCER_NAME" \
    --output text \
    --query LoadBalancerDescriptions[0].ListenerDescriptions[0].Listener.SSLCertificateId
  )

  aws elb create-load-balancer-listeners \
    --load-balancer-name "$LOAD_BALANCER_NAME" \
    --listeners "Protocol=HTTPS,LoadBalancerPort=$PORT,InstanceProtocol=HTTP,InstancePort=$PORT,SSLCertificateId=$SSL_CERTIFICATE_ID" \
    >/dev/null
}

create_service() {
  NAME=$1

  aws ecs create-service \
    --cluster "$CLUSTER" \
    --service-name "$NAME" \
    --task-definition "$NAME" \
    --load-balancers "loadBalancerName=$LOAD_BALANCER_NAME,containerName=$NAME,containerPort=3000" \
    --role "$CONTAINER_ROLE" \
    --desired-count 1 \
    >/dev/null
}

update_service() {
  NAME=$1

  # Assume we don't have enough resources to actually run the task twice. For
  # Overview, the limiting resource is ports: only one version of the task can
  # run at a time because we have only one instance in EC2 and our port numbers
  # are hard-coded; for rolling deploys, we'd be better off just paying for a
  # second instance instead of spending the developer time making things work on
  # a single instance.

  # We print to stdout because this is fragile. It's important the developer
  # know when the service is offline -- especially if the new version of the
  # task doesn't start up as expected.

  >&2 echo "Updating task definition..."
  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$NAME" \
    --task-definition "$NAME" \
    --desired-count 1 \
    >/dev/null

  >&2 echo "Finding old version of the task..."
  task=$(aws ecs list-tasks \
    --cluster "$CLUSTER" \
    --service-name "$NAME" \
    --query taskArns[0] \
    --output text)

  >&2 echo "Stopping old version of the task..."
  aws ecs stop-task \
    --cluster "$CLUSTER" \
    --task "$task" \
    >/dev/null

  >&2 echo "Waiting for new version to spin up..."
  aws ecs wait services-stable \
    --cluster "$CLUSTER" \
    --services "$NAME"
}

NAME="$1"

if [ -z "$NAME" ]; then
  >&2 echo "Usage: $0 [plugin-name]"
  >&2 echo
  >&2 echo "Valid plugins:"
  grep -v '#' "$DIR"/plugins.txt | cut -d' ' -f2 | sed -e 's/^/  /' >&2
  exit 1
fi

line=`grep $NAME "$DIR"/plugins.txt`

if [ -z "$line" ]; then
  >&2 echo "There is no plugin called $NAME. Have you run ./register.sh with this name?"
  exit 1
fi

line_array=($line)
PORT=${line[0]}
MEMORY_LIMIT=${line[2]}

create_or_update_task_definition $PORT $NAME $MEMORY_LIMIT
if `is_service_defined $NAME`; then
  update_service $NAME
else
  add_elb_listener $PORT
  create_service $NAME
fi
