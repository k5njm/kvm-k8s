#!/bin/bash

WORKER_COUNT=20
WORKER_MEM=2048
WORKER_NAME_PREFIX=k8sworker

MASTER_MEM=2048
MASTER_NAME_PREFIX=k8smaster

SOURCE_IMAGE_URL=http://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
CHECKSUM_URL=https://cloud-images.ubuntu.com/focal/current/SHA256SUMS

IMAGE_PATH="../images"
SOURCE_IMAGE_NAME="${SOURCE_IMAGE_URL##*/}" # focal-server-cloudimg-amd64.img

MACHINE_PATH="../machines"

if [ -f "$IMAGE_PATH/$SOURCE_IMAGE_NAME" ]; then
    echo $SOURCE_IMAGE_NAME exists, Checking to see if we have the latest...
    CHECKSUM_ON_DISK=$(sha256sum -b $IMAGE_PATH/$SOURCE_IMAGE_NAME | awk '{print $1}')

    curl -s $CHECKSUM_URL | grep $SOURCE_IMAGE_NAME | grep $CHECKSUM_ON_DISK
    if [ $? -eq 0 ]; then
        echo Checksums match, skipping download
    else
        echo Local copy is outdated, grabbing $SOURCE_IMAGE_URL
        pushd $IMAGE_PATH
        rm $SOURCE_IMAGE_NAME
        wget $SOURCE_IMAGE_URL
        popd
    fi 
else
    echo Grabbing $SOURCE_IMAGE_URL
    pushd $IMAGE_PATH
    wget $SOURCE_IMAGE_URL
    popd
fi

sleep 1
#qemu-img resize $IMAGE_PATH/$SOURCE_IMAGE_NAME 10G

for i in $(seq -f '%02g' 0 $WORKER_COUNT)
    do 

        export IP=$(expr 50 + $i) # Generate IPs sequentially, starting at x.x.x.50

        if [ $i -gt 0 ]; then
            export INSTANCE_ID=$WORKER_NAME_PREFIX$i
            MEM=$WORKER_MEM
            echo "10.0.1.$IP" >> ../ansible/hosts
        else
            export INSTANCE_ID=$MASTER_NAME_PREFIX
            MEM=$MASTER_MEM
            echo "[master]" > ../ansible/hosts
            echo "10.0.1.$IP" >> ../ansible/hosts
            echo "" >> ../ansible/hosts
            echo "" >> ../ansible/hosts

            echo "[workers]" >> ../ansible/hosts

        fi
        
        echo Creating Instance node $INSTANCE_ID
        
        # remove existing instance(s)
        sudo virsh destroy $INSTANCE_ID || true
        sudo virsh undefine $INSTANCE_ID || true
        sudo rm -r $MACHINE_PATH/$INSTANCE_ID

        # Generate Metadata, unique per Instance ID
        mkdir -p $MACHINE_PATH/$INSTANCE_ID
        { echo instance-id: $INSTANCE_ID; echo local-hostname: $INSTANCE_ID; } > $MACHINE_PATH/$INSTANCE_ID/meta-data
        envsubst < user-data > $MACHINE_PATH/$INSTANCE_ID/user-data

        # create a disk to attach with some user-data and meta-data
        pushd $MACHINE_PATH/$INSTANCE_ID/
        genisoimage -output cidata.iso -volid cidata -joliet -rock user-data meta-data


        # create a new qcow image to boot, backed by your original image
        pwd
        qemu-img create -F qcow2 -f qcow2 -b ../$IMAGE_PATH/$SOURCE_IMAGE_NAME $INSTANCE_ID.img 10G

        guestfish <<_EOF_
        add $INSTANCE_ID.img
        run
        mount /dev/vda1 /
        write /etc/cloud/cloud.cfg.d/custom-networking.cfg "network:\n  version: 1\n  config:\n    - type: physical\n      name: enp1s0\n      subnets:\n        - type: static\n          address: 10.0.1.$IP/22\n          gateway: 10.0.0.1\n          dns_nameservers:\n            - 10.0.0.1\n          dns_search:\n            - example.com\n"
              
_EOF_


        sudo virt-install \
        --name=$INSTANCE_ID \
        --ram=$MEM \
        --vcpus=4 \
        --import \
        --disk path=$INSTANCE_ID.img,format=qcow2 \
        --disk path=cidata.iso,device=cdrom \
        --os-variant=ubuntu20.04 \
        --network network=bridged-network,model=virtio \
        --graphics vnc,listen=0.0.0.0 \
        --noautoconsole \

        popd

    done

sudo virsh list

cat ../ansible/hosts
export ANSIBLE_HOST_KEY_CHECKING=false
ansible-playbook -i ../ansible/hosts ../ansible/playbook