#!/bin/bash

master_node_ids=($(docker exec -it redis-cluster-manual-failover-redis-a1-1 redis-cli cluster nodes | grep master | awk '{print $1}'))
redis_b_host_ips=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps | grep 'redis-cluster-manual-failover-redis-b[123]' | awk '{print $1}'))

echo "Joining nodes to cluster"
for redis_b_host_ip in $redis_b_host_ips; do
    echo "Joining node: $redis_b_host_ip"
    docker exec -it redis-cluster-manual-failover-redis-a1-1 redis-cli cluster meet $redis_b_host_ip 6379
done

# allow cluster to update before attempting configure additional replication
sleep 2

# configure the newly added nodes as replicas of the original master nodes
echo "Configuring node as replicas"
for i in {1..3}; do
    master_index=$((i-1))
    master_id=${master_node_ids[$master_index]}
    echo "Replicating master: $master_id"
    docker exec -it redis-cluster-manual-failover-redis-b$i-1 redis-cli cluster replicate $master_id
done
