#!/usr/bin/env bash

set -eo pipefail

[[ -n "${VERBOSE}" ]] && set -x

ssh-keygen -R k8s-master
ssh-keygen -R k8s-worker-0
ssh-keygen -R k8s-worker-1
ssh-keygen -R 192.168.1.140
ssh-keygen -R 192.168.1.146
ssh-keygen -R 192.168.1.147

