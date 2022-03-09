# Setup baremetal instance with Ansible

## How to subscribe the host with Red Hat
The host is subscribed with RH using an activation key, for instructions on how to create the activation key check [Creating Red Hat Customer Portal Activation Keys](https://access.redhat.com/articles/1378093)

The data is stored in the file **group_vars/all/subscription.data**.  The variables defined in this file are called from the ansible playbook.
```
subscription_activationkey: 1-234381329
subscription_org_id: 19704701
```
It is a good idea to encrypt this file with ansible-vault, for example to encrypt the file with the password stored in the file vault-id use a command like:
```
$ ansible-vault encrypt --vault-id vault-id secrets
```

## How to add the ec2-user ssh key to ansible

The playbook needs access to the private ssh key used to connect to the host as the user ec2-user.  Actually it is not the playbook itself but the environment which has access to the ssh private key.

To make the ssh private key available add it to an ssh-agent by running the following commands:

```
$ ssh-agent bash
$ ssh-add ~/.ssh/upi-ssh
```
Verify that the key is available with the following commands, both public keys must match:
```
$ ssh-add -L
ssh-rsa AAAAB3NzaC1...jBI0mJf/kTbahNNmytsPOqotr8XR+VQ== jjerezro@jjerezro.remote.csb

$ cat ~/.ssh/upi-ssh.pub 
ssh-rsa AAAAB3NzaC1...jBI0mJf/kTbahNNmytsPOqotr8XR+VQ== jjerezro@jjerezro.remote.csb
```

## Running the playbook

Run the playbook with the following command:

```
$ ansible-playbook -i inventory -vvv setup_metal.yaml --vault-id vault-id
```
