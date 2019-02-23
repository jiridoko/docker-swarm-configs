#!/bin/bash
docker stack deploy prometheus -c prometheus.yml --prune
