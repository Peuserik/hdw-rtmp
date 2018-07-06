#! /bin/bash
# Create a external IP address
# Create an A record entry with digital ocean
# deploy the application
# enjoy


namespace="$1"

# Create an IP address with gcloud
gcloud compute addresses create $namespace --global

# Get IP address from gcloud
IP = gcloud compute addresses list --format='value(ADDRESS)' --filter="NAME = $namespace"

# Create DNS entry with digital ocean
curl -X POST -H "Content-Type: application/json" \
-d '{"type":"A","name"$namespace","data":$IP","priority":null,"port":null,"ttl":1800,"weight":null,"flags":null,"tag":null}' \
-H "Authorization: Bearer 8681037e6bfb1dc2daa1b37cdeb7b93a75d2426181e8f8e424f3dfbd932131a5" \
https://api.digitalocean.com/v2/domains/peuserik.de/records


# deploy the app
kubectl apply -f kubernetes



