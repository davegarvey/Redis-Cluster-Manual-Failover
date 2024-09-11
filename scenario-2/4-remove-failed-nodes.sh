#!/bin/bash

failed_nodes=($(docker exec -it scenario-2-redis-b1-1 redis-cli CLUSTER NODES | grep -E 'fail\b' | awk '{print $1}'))

echo "Forgetting failed nodes"
for i in {1..3}; do
    for (( j=0; j<${#failed_nodes[@]}; j++ )); do
        docker exec -it scenario-2-redis-b$i-1 redis-cli CLUSTER FORGET ${failed_nodes[i]}
    done
done
