#!/bin/bash

for i in {1..3}; do
    docker exec -it redis-cluster-manual-failover-redis-b$i-1 redis-cli cluster failover takeover
done
