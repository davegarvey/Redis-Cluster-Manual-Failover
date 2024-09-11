#!/bin/bash

echo "Promoting 'b' nodes (123) to master"
for i in {1..3}; do
    docker exec -it scenario-2-redis-b$i-1 redis-cli cluster failover takeover
done
