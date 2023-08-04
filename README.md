# kvm-k8s
> Deploy a multi-node Kubernetes Cluster onto Linux with kubeadm using Terraform, cloudinit, and KVM. Useful for learning kubeadm and self-hosted k8s cluster administration. 

Inspired by: https://sumit-ghosh.com/articles/create-vm-using-libvirt-cloud-images-cloud-init/

Using the latest cloud image of Ubuntu:
```sh
$ wget http://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
```

Now refactored into Terraform!

```sh
cd terraform
terraform plan
terraform apply
```

To remove:
```sh
terraform destroy
```