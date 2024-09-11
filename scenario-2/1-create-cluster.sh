#!/bin/bash

# create cluster initially with just 'a' nodes
redis_a_host_ips=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}:6379{{end}}' $(docker ps | grep scenario-2-redis-a | awk '{print $1}'))
docker exec -it scenario-2-redis-a1-1 \
    redis-cli \
        --cluster create $redis_a_host_ips \
        --cluster-replicas 1 \
        --cluster-yes

# allow cluster updates to happen before proceeding
sleep 7

# store original master node ids
master_node_ids=($(docker exec -it scenario-2-redis-a1-1 redis-cli cluster nodes | grep master | awk '{print $1}'))

# add the 'b' nodes to the cluster
redis_b_host_ips=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps | grep scenario-2-redis-b | awk '{print $1}'))
echo "Joining nodes to cluster"
for redis_b_host_ip in $redis_b_host_ips; do
    echo "Joining node: $redis_b_host_ip"
    docker exec -it scenario-2-redis-a1-1 redis-cli cluster meet $redis_b_host_ip 6379
done

# allow cluster updates to happen before proceeding
sleep 7

# configure 3 of the 'b' nodes as replicas of other b nodes
echo "Configuring b nodes (456) as replicas"
redis_b123_host_ips=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps | grep 'scenario-2-redis-b[123]' | awk '{print $1}'))
ip_csv=$(echo "$redis_b123_host_ips" | tr '\n' '|')
ip_csv=${ip_csv%?}
redis_b123_node_ids=($(docker exec -it scenario-2-redis-a1-1 redis-cli cluster nodes | grep -E "$ip_csv" | awk '{print $1}'))
node_index=0
for i in {4..6}; do
    node_id=${redis_b123_node_ids[$node_index]}
    echo "Replicating: $node_id"
    docker exec -it scenario-2-redis-b$i-1 redis-cli cluster replicate $node_id
    ((node_index++))
done

# allow cluster updates to happen before proceeding
sleep 7

# configure 3 of the 'b' nodes as replicas of the original master nodes
echo "Configuring b nodes (123) as replicas"
node_index=0
for i in {1..3}; do
    node_id=${master_node_ids[$node_index]}
    echo "Replicating: $node_id"
    docker exec -it scenario-2-redis-b$i-1 redis-cli cluster replicate $node_id
    ((node_index++))
done

# allow cluster updates to happen before proceeding
sleep 7

echo "Adding record to database"
docker exec -it scenario-2-redis-a1-1 redis-cli -c set test data

echo "Cluster Config:"
docker exec -it scenario-2-redis-a1-1 redis-cli cluster nodes
