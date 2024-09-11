#!/bin/bash

redis_host_ips=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}:6379{{end}}' $(docker ps | grep redis-cluster-manual-failover-redis-a | awk '{print $1}'))

docker exec -it redis-cluster-manual-failover-redis-a1-1 \
    redis-cli \
        --cluster create $redis_host_ips \
        --cluster-replicas 1 \
        --cluster-yes
