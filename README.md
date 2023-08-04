# Automatically deployed Kubernetes Cluster, using Ubuntu cloud images and cloud-init.

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