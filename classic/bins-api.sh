#!/bin/bash
docker stack deploy bins-api -c bins-api.yml --prune
