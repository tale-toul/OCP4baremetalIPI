# Set up the baremetal instance with Ansible

## Subscribe the host with Red Hat
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

## Add the ec2-user ssh key

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

Before running the playbook make sure the EC2 instance is fully initialized and accepting ssh connections, this may take a few minutes after creation.

![Metal instance ready](images/ec2-ready.png)

Run the playbook with the following command:

```
$ ansible-playbook -i inventory -vvv setup_metal.yaml --vault-id vault-id 
```
## Rebooting the host after OS update
The playbook contains a task to update the Operating System, depending on what packages were updated, the kernel for example, the host may require a reboot.

A full host reboot can take between 10 and 20 minutes to complete.

To try and minimize the chances of unnecessary reboots, the playbook pauses and prompts the user if the host should be rebooted or not. If the playbook has been run in verbose mode (-vvv) as it should, the list of updated packages can be check in the output from the previous taks:
```
    "results": [
        "Installed: samba-client-libs-4.14.5-9.el8_5.x86_64", 
        "Installed: rubygem-bigdecimal-1.3.4-109.module+el8.5.0+14275+d9c243ca.x86_64", 
        "Installed: rubygem-rdoc-6.0.1.1-109.module+el8.5.0+14275+d9c243ca.noarch", 
        "Installed: rubygem-psych-3.0.2-109.module+el8.5.0+14275+d9c243ca.x86_64", 
        "Installed: samba-common-4.14.5-9.el8_5.noarch", 
        "Installed: libsmbclient-4.14.5-9.el8_5.x86_64", 
        "Installed: samba-common-libs-4.14.5-9.el8_5.x86_64", 
        "Installed: ruby-libs-2.5.9-109.module+el8.5.0+14275+d9c243ca.x86_64", 
        "Installed: rubygems-2.7.6.3-109.module+el8.5.0+14275+d9c243ca.noarch", 
        "Installed: rubygem-openssl-2.1.2-109.module+el8.5.0+14275+d9c243ca.x86_64", 
        "Installed: rubygem-json-2.1.0-109.module+el8.5.0+14275+d9c243ca.x86_64", 
        "Installed: ruby-irb-2.5.9-109.module+el8.5.0+14275+d9c243ca.noarch", 
        "Installed: libwbclient-4.14.5-9.el8_5.x86_64", 
        "Installed: rubygem-did_you_mean-1.2.0-109.module+el8.5.0+14275+d9c243ca.noarch", 
        "Installed: ruby-2.5.9-109.module+el8.5.0+14275+d9c243ca.x86_64", 
        "Installed: rubygem-io-console-0.4.6-109.module+el8.5.0+14275+d9c243ca.x86_64", 
    ]
}

TASK [pause] *********************************************************************************************************************************************************************************
task path: /home/user1/OCP4baremetalIPI/Ansible/setup_metal.yaml:82
Thursday 10 March 2022  09:30:28 +0100 (0:00:06.661)       0:04:01.275 ******** 
[pause]
Operating System has been updated.  Reboot the host? (yes|no):
[[ok: [54.243.59.185] => {
    "changed": false, 
    ...
    "user_input": "yes"
}
```
