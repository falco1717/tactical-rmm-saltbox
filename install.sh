#!/bin/bash
# Traefik Cert Dumper Install
docker compose -f cert-dumper/docker-compose.yml up -d
sleep 30


# Get the domain, username, and password from the accounts.yml file
domain=$(awk '$1=="user:" {getline; while ($1!="domain:") {getline}; print $2}' /srv/git/saltbox/accounts.yml)
username=$(awk '$1=="user:" {getline; while ($1!="name:") {getline}; print $2}' /srv/git/saltbox/accounts.yml)
password=$(awk '/^user:/ {p=1} p && /^  pass:/ {print $2; exit}' /srv/git/saltbox/accounts.yml)

# Check if the domain, username, or password is empty
if [ -z "$domain" ] || [ -z "$username" ] || [ -z "$password" ]; then
    echo "Domain, username, or password not found in accounts.yml"
    exit 1
fi

# Update values in tactical-rmm .env file
sed -i "s/yourdomain.com/$domain/g" tactical-rmm/.env
sed -i "s/username/$username/g" tactical-rmm/.env
sed -i "s/password/$password/g" tactical-rmm/.env

# Update values in cert.sh file
sed -i "s/yourdomain.com/$domain/g" cert-dumper/cert.sh

echo "Updated values:"
cat tactical-rmm/.env
cat cert-dumper/cert.sh

# Copies Traefik rules ovwr for sub domain forwarding with nginx
cp traefik/rmm.yml /opt/traefik/
sed -i "s/yourdomain.com/$domain/g" /opt/traefik/rmm.yml

# Updates .env file with exported cert information
sh cert-dumper/cert.sh

# Tactical-rmm docker compose install
docker compose -f tactical-rmm/docker-compose.yml up -d
sleep 40

# Updates mesh_data config.json file domain entries
dashdomain="dash.${domain}"
sed -i "s/172.50.0.200/$dashdomain/g" /opt/tactical-rmm/mesh_data/config.json

# Fix Permissions
sudo chown -R $username:$username /opt/tactical-rmm/
sudo chmod 755 -R /opt/tactical-rmm/

# Updates Mesh_data config.json file port number
sed -i 's/:4443\b/:443/g' "/opt/tactical-rmm/mesh_data/config.json"

# Restarts mesh central containee
docker restart trmm-meshcentral
