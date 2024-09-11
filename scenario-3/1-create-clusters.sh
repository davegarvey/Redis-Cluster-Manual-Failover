#!/bin/bash

echo "Creating cluster A"
redis_a_host_ips=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}:6379{{end}}' $(docker ps | grep scenario-3-redis-a | awk '{print $1}'))
docker exec -it scenario-3-redis-a1-1 \
    redis-cli \
        --cluster create $redis_a_host_ips \
        --cluster-replicas 1 \
        --cluster-yes

echo "Creating cluster B"
redis_b_host_ips=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}:6379{{end}}' $(docker ps | grep scenario-3-redis-b | awk '{print $1}'))
docker exec -it scenario-3-redis-b1-1 \
    redis-cli \
        --cluster create $redis_b_host_ips \
        --cluster-replicas 1 \
        --cluster-yes

# wait for cluster config to propagate
sleep 7

echo "Creating test data"
docker exec -it scenario-3-redis-a1-1 redis-cli -c set test data
