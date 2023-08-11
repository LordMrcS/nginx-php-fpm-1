#!/bin/bash

# Update nginx to match worker_processes to no. of cpu's
procs=$(cat /proc/cpuinfo | grep processor | wc -l)
sed -i -e "s/worker_processes  1/worker_processes $procs/" /etc/nginx/nginx.conf

# Always chown webroot for better mounting
find /usr/share/nginx/html -not -user www-data -execdir chown www-data:www-data {} \+

# Start supervisord and services
supervisord -n -c /etc/supervisord.conf
