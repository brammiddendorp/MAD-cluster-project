#!/bin/bash

PACK=$(zenity --list --title="PACKAGE MANAGER" --text="Choose your package manager" --column="Package manager" --column="Distro" dnf "Fedora" \
apt "Ubuntu")
MASTER=$(zenity --entry --title="IP" --text="What is the IP address of your server?")
DOMAIN=$(zenity --entry --title="DOMAIN" --text="What is your domain?")
ADMIN_PASS=$(zenity --entry --title="PASSWORD" --text="Please specify an admin password")

sudo $PACK install -y git ansible pwgen

# BASIS
# Get playbook
git clone https://github.com/spantaleev/matrix-docker-ansible-deploy.git ~/matrix-docker-ansible-deploy
mkdir ~/matrix-docker-ansible-deploy/inventory/host_vars/matrix.$DOMAIN
cp ~/matrix-docker-ansible-deploy/examples/vars.yml ~/matrix-docker-ansible-deploy/inventory/host_vars/matrix.$DOMAIN/vars.yml
# Set domain
sed -i 's/YOUR_BARE_DOMAIN_NAME_HERE/'$DOMAIN'/' ~/matrix-docker-ansible-deploy/inventory/host_vars/matrix.$DOMAIN/vars.yml
# Set homeserver secret
sed -i -e "s/matrix_homeserver_generic_secret_key: ''/matrix_homeserver_generic_secret_key: '$(pwgen -s 64 1)'/" ~/matrix-docker-ansible-deploy/inventory/host_vars/matrix.$DOMAIN/vars.yml
# Set lets encrypt email
sed -i "s/matrix_ssl_lets_encrypt_support_email: ''/matrix_ssl_lets_encrypt_support_email: 'webmaster@$DOMAIN'/" ~/matrix-docker-ansible-deploy/inventory/host_vars/matrix.$DOMAIN/vars.yml
# Set postgres password
sed -i -e "s/matrix_postgres_connection_password: ''/matrix_postgres_connection_password: '$(pwgen -s 64 1)'/" ~/matrix-docker-ansible-deploy/inventory/host_vars/matrix.$DOMAIN/vars.yml

cp ~/matrix-docker-ansible-deploy/examples/hosts ~/matrix-docker-ansible-deploy/inventory/hosts
# set server domain
sed -i 's/matrix.<your-domain>/matrix.'$DOMAIN'/' ~/matrix-docker-ansible-deploy/inventory/hosts
# set server IP
sed -i "s/<your-server's external IP address>/$MASTER/" ~/matrix-docker-ansible-deploy/inventory/hosts

# EXTRAS
# Set up Synapse-admin
tee -a ~/matrix-docker-ansible-deploy/inventory/host_vars/matrix.$DOMAIN/vars.yml > /dev/null << EOF
matrix_synapse_admin_enabled: true
#Dark theme
matrix_client_element_default_theme: 'dark'
#Custom logo
matrix_client_element_welcome_logo: "https://raw.githubusercontent.com/130948/MAD-cluster-project/c94b6e62a91afdecf56b68c495bca0577d6f04c0/logo.png"
#OpenID support
matrix_nginx_proxy_proxy_matrix_client_api_forwarded_location_synapse_oidc_api_enabled: true
EOF

# ACTIVATE
#install + start
ansible-playbook -i ~/matrix-docker-ansible-deploy/inventory/hosts ~/matrix-docker-ansible-deploy/setup.yml --tags=setup-all,start
#register admin
ansible-playbook -i ~/matrix-docker-ansible-deploy/inventory/hosts ~/matrix-docker-ansible-deploy/setup.yml --extra-vars='username=admin password='$ADMIN_PASS' admin=yes' --tags=register-user

# SET UP DIMENSION
#Create Dimension user
ansible-playbook -i ~/matrix-docker-ansible-deploy/inventory/hosts ~/matrix-docker-ansible-deploy/setup.yml --extra-vars='username=dimension password='$ADMIN_PASS' admin=no' --tags=register-user
#Set Dimension variables
tee -a ~/matrix-docker-ansible-deploy/inventory/host_vars/matrix.$DOMAIN/vars.yml > /dev/null << EOF
#Dimension
matrix_dimension_enabled: true
matrix_dimension_admins:
  - "@dimension:{{ matrix_domain }}"
matrix_dimension_access_token: $(curl -X POST --header 'Content-Type: application/json' -d '{
    "identifier": { "type": "m.id.user", "user": "dimension" },
    "password": "$ADMIN_PASS",
    "type": "m.login.password"
}' 'https://matrix.$DOMAIN/_matrix/client/r0/login' | grep -oP '(?<="access_token":).*(?=,"home_server")')
EOF
#Redeploy
ansible-playbook -i ~/matrix-docker-ansible-deploy/inventory/hosts ~/matrix-docker-ansible-deploy/setup.yml --tags=setup-all,start
