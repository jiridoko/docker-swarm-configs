#!/bin/bash
docker stack deploy postgres -c postgres.yml --prune
