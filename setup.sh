#!/bin/bash
MASTER=$1
DOMAIN=$2
ADMIN_PASS=$3
PACK=$4

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

# THEMING
#Dark theme
matrix_client_element_default_theme: 'dark'
#Logo
matrix_client_element_welcome_logo: "https://raw.githubusercontent.com/130948/MAD-cluster-project/c94b6e62a91afdecf56b68c495bca0577d6f04c0/logo.png"
EOF

# ACTIVATE
#install + start
ansible-playbook -i ~/matrix-docker-ansible-deploy/inventory/hosts ~/matrix-docker-ansible-deploy/setup.yml --tags=setup-all,start
#register admin
ansible-playbook -i ~/matrix-docker-ansible-deploy/inventory/hosts ~/matrix-docker-ansible-deploy/setup.yml --extra-vars='username=admin password='$ADMIN_PASS' admin=yes' --tags=register-user
