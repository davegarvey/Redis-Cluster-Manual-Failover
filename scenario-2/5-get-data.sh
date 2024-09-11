#!/bin/bash

echo "Getting test data"
docker exec -it scenario-2-redis-b1-1 redis-cli -c GET test
