#!/bin/bash

echo "Killing redis 'a' containers"
docker kill $(docker ps -q -f name=scenario-2-redis-a)
