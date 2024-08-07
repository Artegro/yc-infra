#!/bin/bash

set -e

cd terraform
TF_IN_AUTOMATION=1 terraform init -upgrade
TF_IN_AUTOMATION=1 terraform apply -auto-approve
bash generate_inventory.sh > ../kubespray_inventory/hosts.ini
bash generate_credentials_velero.sh > ../kubespray_inventory/credentials-velero
bash generate_etc_hosts.sh > ../kubespray_inventory/etc-hosts

cd ../
sudo rm -rf kubespray/inventory/mycluster
mkdir -p kubespray/inventory
cp -rfp kubespray_inventory kubespray/inventory/mycluster


sudo pip3 install -r kubespray/requirements.txt

export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i kubespray/inventory/mycluster/hosts.ini --user ubuntu --become wait-for-server-to-start.yml 

cd kubespray
ansible-playbook -i inventory/mycluster/hosts.ini --user ubuntu  --become cluster.yml    
#sudo chown artegro -R inventory
cd ../terraform
MASTER_1_PRIVATE_IP=$(terraform output -json instance_group_masters_private_ips | jq -j ".[0]")
MASTER_1_PUBLIC_IP=$(terraform output -json instance_group_masters_public_ips | jq -j ".[0]")
sed -i -- "s/$MASTER_1_PRIVATE_IP/$MASTER_1_PUBLIC_IP/g" ../kubespray/inventory/mycluster/artifacts/admin.conf

mkdir -p ~/.kube 
cp ../kubespray/inventory/mycluster/artifacts/admin.conf ~/.kube/config