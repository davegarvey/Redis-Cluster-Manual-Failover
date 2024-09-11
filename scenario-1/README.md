# Redis-Cluster-Manual-Failover

The Docker Compose file creates 12 Redis instances, which are named as two groups 'A' and 'B', with six nodes in each group. This enables us to have two standard Redis clusters with three masters and 3 replicas in each group.

The idea is that group A is the 'primary', but in the event of a problem group B can take over. In order to do this we need to get the data from group A into group B. This PoC attempts to use standard Redis replication to do this, by adding some nodes from group B as replicas of the group A masters. Then, where there is a failure, use the Redis CLI to orchestrate the failover and create a working cluster using the group B nodes.

Note that this is not best practice, but shows how such as failover can be performed.

Bash scripts have been provided to streamline the process for commands that require loops etc.

## 1. Bring up the depoyment

```bash
docker compose up -d
```

Note: when bringing the deployment down, ensure to include the `-v` flag so that the volumes are also removed e.g. `docker compose down -v`

## 2. Run setup to create initial cluster

```bash
./1-create-cluster.sh
```

Only one cluster is created, for group A nodes, the other remaining containers (group B) are left as empty Redis nodes. They will become the active cluster when the group A nodes fail.

## 3. Add a record to cluster A

```bash
docker exec -it redis-cluster-manual-failover-redis-a1-1 redis-cli -c set a a
```

Using the `-c` flag enables cluster mode for the Redis CLI, which automatically redirects the `set` command to the correct shard.

## 4. Join three of the empty group B nodes to the cluster as replicas

```bash
./2-join-more-replicas.sh
```

## 5. Kill the group A nodes

This command kills all the containers running the original cluster nodes from the `a` group (3 masters and 3 replicas):

```bash
docker kill $(docker ps -q -f name=redis-cluster-manual-failover-redis-a)
```

The cluster will now be down, which you can validate with this command that should return `cluster_state:fail` (note that it may take up to 10 seconds for the cluster state to update - check the logs to see it happen):

```bash
docker exec -it redis-cluster-manual-failover-redis-b1-1 redis-cli cluster info | grep cluster_state
```
 
Now we need to repair the cluster by adding the remaining group B nodes and turning the existing replicas into masters.

## 6. Force the replicas to take over the cluster

Run this script to force the remaining `b` replicas to become masters: 

```bash
./3-cluster-takeover.sh
```

The replicas will now be masters. The script uses the `takeover` parameter, which forces the replica to promote themselves to a master without needing agreement from the rest of the cluster.

The cluster state will return to `ok` (as previously, the state change is not immediate):
```bash
docker exec -it redis-cluster-manual-failover-redis-b1-1 redis-cli cluster info | grep cluster_state
```

## 7. Remove failed nodes from cluster

Run this script to instruct the `b` master nodes to forget all of the failed `a` nodes:

```bash
./4-remove-failed-nodes.sh
```

This will produce 18 `OK` responses, as each of the 3 `b` master nodes forgets the 6 failed `a` nodes.

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
