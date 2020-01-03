# Redis-Cluster-Manual-Failover

The Docker Compose file creates 12 Redis instances, which are named as two groups 'A' and 'B', with six nodes in each group. This enables us to have two standard Redis clusters with three masters and 3 replicas in each group.

The idea is that group A is the 'primary', but in the event of a problem group B can take over. In order to do this we need to get the data from group A into group B. This PoC attempts to use standard Redis replication to do this, by adding some nodes from group B as replicas of the group A masters. Then, where there is a failure, use the Redis CLI to orchestrate the failover and create a working cluster using the group B nodes.

Is this a wise idea? Probably not!

## 1. Run setup to create initial cluster

    docker exec -it redis-cluster-manual-failover_redis-a1_1 redis-cli --cluster create $(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}:6379{{end}}' $(docker ps | grep redis-cluster-manual-failover_redis-a | awk '{print $1}')) --cluster-replicas 1

Follow the prompts to create the cluster.

Only one cluster is created, for group A nodes, the other remaining containers (group B) are left as empty Redis nodes. They will become the active cluster when the group A nodes fail.

## 2. Add a record to cluster A

    docker exec -it redis-cluster-manual-failover_redis-a<CORRECT_SHARD_FOR_KEY>_1 redis-cli set a a

You will need to use the correct shard for the cluster A key `a`.

## 3. Join three of the empty group B nodes to the cluster 

Get the IPs of the group B nodes to add:

    docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}} 6379{{end}}' $(docker ps | grep redis-cluster-manual-failover_redis-b[123] | awk '{print $1}')

Run this command for each IP/port pair returned, to add them as replicas:

    docker exec -it redis-cluster-manual-failover_redis-a1_1 redis-cli cluster meet <IP> <PORT>

## 4. Set the newly joined nodes as replicas

Note the node IDs of the masters and the newly added nodes:

    docker exec -it redis-cluster-manual-failover_redis-a1_1 redis-cli cluster nodes

Now join the new nodes as replicas to the masters by running this command on each of the new nodes, using a different master node id for each:

    docker exec -it redis-cluster-manual-failover_redis-b<ID>_1 redis-cli cluster replicate <MASTER NODE ID>

## 5. Kill the group A nodes

    docker kill $(docker ps -q -f name=redis-cluster-manual-failover_redis-a)

The cluster will now be down, which you can test with this command:

    docker exec -it redis-cluster-manual-failover_redis-b1_1 redis-cli get a
 
Now we need to repair the cluster by adding the remaining group B nodes and turning the existing replicas into masters.

## 6. Force the replicas to take over the cluster

Run this command on the three group B replica nodes (1/2/3):

    docker exec -it redis-cluster-manual-failover_redis-b<ID>_1 redis-cli cluster failover takeover

The replicas will now be masters, but the cluster will still be down as there is no quorum, so we must remove the failed nodes to establish a quorum.

The `takeover` parameter forces the replica to promote itself to a master without needing agreement from the rest of the cluster.

## 7. Remove failed nodes from cluster

Run this command on the three group B replica nodes (1/2/3), passing in the Redis node ID for each of the failed nodes:

    docker exec -it redis-cluster-manual-failover_redis-b<ID>_1 redis-cli cluster forget <FAILED_NODE_ID>

So this should be run 18 times in total, to cover all node combinations! When the command is run for a failed node, the remaining `forget` commands for that failed node need to be run within 60 seconds to prevent the previous state from propagating from other nodes.

## 8. Add new nodes to the cluster

Now we can add the remaining group B nodes to the cluster to act as replicas. Get their IP/ports:

    docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}} 6379{{end}}' $(docker ps | grep redis-cluster-manual-failover_redis-b[456] | awk '{print $1}')

Run this command for each IP/port pair returned, to add them as replicas:

    docker exec -it redis-cluster-manual-failover_redis-b1_1 redis-cli cluster meet <IP> <PORT>

## 9. Set remaining group B nodes as replicas

Note the node IDs of the masters and the newly added nodes:

    docker exec -it redis-cluster-manual-failover_redis-b1_1 redis-cli cluster nodes

Now join the new nodes as replicas to the masters by running this command on each of the new nodes, using a different master node id for each:

    docker exec -it redis-cluster-manual-failover_redis-b<ID>_1 redis-cli cluster replicate <MASTER NODE ID>

## 10. Check the data still exists

You will need to target the correct node:

    docker exec -it redis-cluster-manual-failover_redis-b<CORRECT_SHARD>_1 redis-cli get a

Hopefully you will find that `a` is returned!

## 11. What's next?

Assuming that the group A nodes are recovered at some point, the process can be resumed in reverse, where three of the group A nodes are added to the cluster as replicas of the group B masters.