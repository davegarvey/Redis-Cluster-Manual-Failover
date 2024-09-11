This scenario uses two 'groups' of Redis nodes to simulate how a cluster split across two data centres could handle the failure of one of the data centres. 

The Redis nodes are initially deployed as a single cluster, with 3 masters and 9 replicas. The idea being that if the DC with the masters fails, that it's possible to force promotion of replica nodes in the other data centre to become masters.

Run the scripts in number sequence to go through the scenario.

**Note**: that due to default timeouts etc, the Redis cluster can take around 5 to 10 seconds before it reacts to changes. Bear this in mind when running the scripts i.e. wait 5-10 seconds between running them, or simply observe the Redis container logs to see when the cluster state changes - as running the scripts too soon may result in erroneous outcomes.

### 1. Create the Cluster

Set up the cluster:

```bash
./1-create-cluster.sh
```

The cluster is initially created using just the 'a' nodes, with 3 masters (m) and 3 replicas (r). For example:

```
a1(m)  a2(m)  a3(m)
 |      |      |
a4(r)  a5(r)  a6(r)
```

The 'b' nodes are then joined to the cluster. Three of the 'b' nodes (b4/5/6) are set to replicate the other 3 'b' nodes (b1/2/3), which are then also set to replicate the original 'a' master nodes (a1/2/3), so the repication topology looks like this:

```
a1(m)         a2(m)         a3(m)
 |-------      |-------      |-------
 |      |      |      |      |      |
a4(r)  b1(r)  a5(r)  b2(r)  a6(r)  b3(r)
        |             |             |
       b4(r)         b5(r)         b6(r)
```

In order to configure a cascading replication such as this (e.g. a1 -> b1 -> b4), it is neccessary to establish the b1 -> b4 replication before the a1 -> b1 replication, as Redis does not allow replicas to replicate other replicas. However, this can be overcome by joining the 'b' nodes after the initial cluster is created, where they are joined as masters that can then be assigned replica duties.

It is configured in this way to simplify failover in the event of the 'a' nodes failing, as the 'b' nodes are already configured in a typical cluster setup, with nodes b1/2/3 ready to become masters with b4/5/6 replicating them:

```
b1(r)  b2(r)  b3(r)
 |      |      |
b4(r)  b5(r)  b6(r)
```

### 2. Cause Cluster Failure

Stop the 'a' node containers using this script:

```bash
./2-cause-cluster-failure.sh
```

This causes the cluster state to change to `down`, as a quorum cannot be achieved without a majority of master nodes being available - and we've just lost all of them.

### 3. Cluster Takeover

Recover the cluster by forcing the 'b' nodes to take over the cluster:

```bash
./3-cluster-takeover.sh
```

This promotes nodes b1/2/3 to master, which restores the cluster state to `ok`.

### 4. Remove Failed Nodes

Remove the failed 'a' nodes from the cluster:

```bash
./4-remove-failed-nodes.sh
```

This tells the 'b' nodes to forget the 'a' nodes. 

To recover these 'a' nodes, their redis hosts should be recreated and added back into the cluster as per the original cluster creation process.

### 5. Display the Test Data

Show that the data created during the cluster creation process has been preserved, and is still available:

```bash
./5-get-data.sh
```

This should show the output `"data"`.
