#!/bin/bash

failed_nodes=($(docker exec -it redis-cluster-manual-failover-redis-b1-1 redis-cli CLUSTER NODES | grep -E 'fail\b' | awk '{print $1}'))

for i in {1..3}; do
    for (( j=0; j<${#failed_nodes[@]}; j++ )); do
        docker exec -it redis-cluster-manual-failover-redis-b$i-1 redis-cli CLUSTER FORGET ${failed_nodes[i]}
    done
done
