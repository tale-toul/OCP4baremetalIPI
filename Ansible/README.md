# Set up the baremetal and Libvirt instances with Ansible

## Subscribe hosts with Red Hat
The EC2 metal host uses RHEL 9, the support and provisioning VMs use RHEL 8, all are subscribed with Red Hat using an activation key, for instructions on how to create the activation key check [Creating Red Hat Customer Portal Activation Keys](https://access.redhat.com/articles/1378093):

RHEL 9.0 is used in the EC2 metal host because python pip version in RHEL 8.6 is too old to install sushy tools.
RHEL 8.6 is used in the provision (and support) VMs because the openshift installer cannot create the bootstrap KVM VM with the version of qemu included in RHEL 9.

1. Go to the [Activation Keys](https://access.redhat.com/management/activation_keys) page
1. Click on new to create an activation key
1. Enter a name for the activation key, this will later be used to as a reference in Ansible.
1. Define a Service Level, only for non free accounts
1. Select whether to use Auto Attach or not.  Enable is a sensible default.
1. Click create

Once created the activacion key data is available at https://access.redhat.com/management/activation_keys.  Click on the activacion key just created and use the Name to populate the variable **subscription_activationkey** and the Organization ID to populate the variable **subscription_org_id**.

The activation key data is stored in the file **Ansible/group_vars/all/subscription.data**.  The variables defined in this file are used by the ansible playbook.
```
subscription_activationkey: 1-234381329
subscription_org_id: 19704701
```
It is recommended to encrypt this file with ansible-vault, for example to encrypt the file with the password stored in the file vault-id use a command like:
```
$ ansible-vault encrypt --vault-id vault-id subscription.data
```
## Keep ssh connections alive

Ansible connects to the managed hosts using ssh, then runs the tasks in the remote host.  It is possible that some tasks take a few minutes to complete, during which time the ssh connection is idle.  Depending on the ssh server configuration on the remote system, ssh connections may be discarded after a certain idle period, if this _timeout_ period is shorter than the time it takes the ansible task to complete, the result will be a failed or hung ansible playbook execution.  

One such case can happen with the tasks that install rpm packages in the remote hosts.  

To avoid this issue it should be possible to configure the ssh client in the same host where ansible is executed to send keepalive packets at regular interval to avoid the ssh server on the managed host to close the connection.  

In most linux systems this can be done at the user or system level. To apply the configuration at user level add the **ServerAliveInterval** option to file ~/.ssh/config.  To apply the configuration at system level add the same optoin to file /etc/ssh/sshd_config:

```
Host *
  ServerAliveInterval 60
```

## Add the common ssh key

Ansible needs access to the _private ssh key_ authorized to connect to the different hosts controlled by these playbooks.  Actually it is not the playbooks but the shell environment which has access to the ssh private key.

To simplify things the same ssh key is authorized in all hosts being managed by the ansible playbooks in this respository.

To make the ssh private key available to the shell, add it to an ssh-agent by running the following commands:

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
## Running the playbook to configure the metal EC2 instance

The inventory file is managed by the ansible playbook, there is no need to add any hostnames to it.

The vault-id file is the one used earlier to encrypt the subscription data.

Run the playbook with the following command:

```
$ ansible-playbook -i inventory -vvv setup_metal.yaml --vault-id vault-id
```

### Variables interface for setup_metal.yaml

The list of variables used by the playbook are:

* **baremetal_public_ip**.- Contains the public Internet facing IP address of the EC2 instance.  This variable is automatically assigned by terraform template **Terraform/main.tf** as an output variable
* **subscription_activationkey** and **subscription_org_id**.- Contain the activation key and organiaztion ID required to subscribe the RHEL host as explained in section [Subscribe hosts with Red Hat](#subscribe-hosts-with-red-hat).  These variables must be assigned by the user.

* **update_OS**.- Whether to update the Operating system and reboot the host (true) or not (false).  Rebooting the EC2 instance is time consuming and may take between 10 and 20 minutes.  This variable is defined in the file **Ansible/group_vars/all/general.var**. 

     Default value: **false**

### Rebooting the host after OS update
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

TASK [pause] 
task path: /home/user1/OCP4baremetalIPI/Ansible/setup_metal.yaml:82
Thursday 10 March 2022  09:30:28 +0100 (0:00:06.661)       0:04:01.275
[pause]
Operating System has been updated.  Reboot the host? (yes|no):
[[ok: [54.243.59.185] => {
    "changed": false, 
    ...
    "user_input": "yes"
}
```
## Set up KVM instances

A separate ansible playbook file (**support_setup.yaml**) is used to configure the KVM virtual machines created previously with terraform, in particular the provisioning and support VMs.

This playbook has the following requirements:

* An [activation key](#subscribe-the-host-with-red-hat) is required to register the VMs with Red Hat.  The activation key used to subscribe the EC2 is used if it is still available.
* An [ssh private key](#add-the-ec2-user-ssh-key) to connect to the VMs. This ssh key is the same used by the EC2 metal instance, the terraform template injects the same ssh key in all KVM VMs and EC2 instance.
* A [pull secret](https://console.redhat.com/openshift/install/metal/user-provisioned) for the Openshift installation.  Download the pull secret and copy it to **Ansible/pull-secret**.  
* In case of redfish based architecture, the network port where sushy tools (redfish for libvirt) provides service in the metal instance is defined in the variable **sushy_tools_port**, it has a default value of 8080.

### Running the playbook for libvirt VMs

The playbook is run with a command like the following, similar to the one used to set up the EC2 instance:

```
$ ansible-playbook -i inventory -vvv support_setup.yaml --vault-id vault-id 
```

### Variables interface for support_setup
The list of variables used by the playbook are:

* **api_vip** 

* **baremetal_private_ip** 

* **baremetal_public_ip**

* **chucky_gateway** 

* **chucky_net_addr**.- Network address for the routable chucky network from which all VMs get an IP address.  Defined and used in **Terraform/libvirt**.  Default value **192.168.30.0/24**
  * **chucky_short_net**.- Network address for the routable chucky network in short form (192.168.30).  This variable is automatically assigned by an ansible task in the **setup_support_services** role.

* **cluster_name**.- Subdomain for the whole cluster DNS name.  For example for a **cluster_name=ocp4** and a **dns_zone=tale.net** the whole cluster domain is **ocp4.tale.net**.  Defined and used by ansible.  Default value **ocp4**.  

* **dns_zone**.- Internal private DNS zone for the Openshift cluster.  This is not resolvable outside the virtual infrastructure.

* **ingress_vip** 

* **managed_password**

* **managed_user** 

* **master_chucky_mac_base**.- MAC address common part for the master NICs in the chucky network.  Defined in **Terraform/libvirt**.  Default value 52:54:00:a9:6d:7

* **master_names**.- List of master node names.  Obtained as an output variable from **Terraform/libvirt**

* **master_provision_mac_base** 

* **number_of_workers**

* **ocp_version** 

* **provision_host_ip**

* **provision_mac**.- MAC address for provision VM NIC in the routable (chucky) network.  Defined in **Terraform/libvirt**.  The letters in the MACs should be in lowercase.  Default value 52:54:00:9d:41:3c

* **provisioning_dhcp_end** 

* **provisioning_dhcp_start** 

* **provision_net_addr** 

* **ssh_certificate**

* **subscription_activationkey** and **subscription_org_id**

* **support_host_ip**

* **sushy_tools_port** 

* **worker_chucky_mac_base**.- MAC address common part for the worker NICs in the chucky network.  Defined in **Terraform/libvirt**.  Default value 52:54:00:a9:6d:
 

* **worker_names**.- List of worker node names.  Obtained as an output variable from **Terraform/libvirt**

* **worker_provision_mac_base** 

### Running tasks via a jumphost with ssh

The KVM VMs are only reachable from the EC2 instance as they are attached to a private network which allows NAT outbound access beyond the EC2 host but only inbound access from the EC2 host, so ther are not directly reacheble from the controlling host where the ansible playbooks are run.

To allow the playbook to run tasks in the KVM VMs the ssh's **ProxyJump** option is used (similar to the **-J** command line option).  With this option an ssh tunnel is created from the controlling host running ansible to the end controlled host (support) passing through the jump host specified in the option.

To use this option with ansible, the ansible variable  **ansible_ssh_common_args** is defined for the host or group in the inventory file.  The options defined here will be added to the ssh command used to connect to the controlled host.

In the following example the hosts in the support group, actually the support VM, with an IP in a private network, for example 192.168.30.3, will be reached by first stablishing an ssh connection to the EC2 instance (3.87.151.210) using the user **ec2-user**, from there the connection to the target host is made (192.168.30.3), since the user in the target host is root and not ec2-user, the variable **ansible_user** is also defined to specify the user that the ssh must use to connect to the target user.  

The EC2 instance's IP address changes after every new execution of the terraform template so that section is dynamicaly added to the inventory file by a previous play in the same playbook.

One important implicit part is that for both hosts: jump and target, the authentication is made with the same ssh key, which is added to the shell as explainend [here](#add-the-ec2-user-ssh-key)
```
[support:vars]
ansible_ssh_common_args='-o ProxyJump="ec2-user@3.87.151.210"' 
ansible_user=root
```
The resulting ssh command would be something like:
```
$ ssh -o 'User="root"' -o ProxyJump=ec2-user@3.87.151.210 192.168.30.3 
```
An equivalent command to the one above is:
```
$ ssh -J ec2-user@3.219.143.250  root@192.168.30.3
```

### Setting up DNS and DHCP

The configuration for DNS and DHCP is applyed using the ansible role **setup_support_services** called from the support_setup playbook.  This role installs the rpm packages required to provide the services, dynamically creates the configuration files using templates and finally enables and starts the DHCP and DNS services.

The creation of the worker entries in the dhcpd.conf template uses a loop to define the MAC address reservation, the IP address and the hostname to assign to the host. The formating string for the mac address takes a base and adds the loop count converted to hexadecimal using 2 characters padded with a zero to the left if necessary.
```
{% for item in worker_names %}
host worker{{ loop.index0 }} {
  hardware ethernet {{ worker_chucky_mac_base }}{{ '%02x' % loop.index0 }};
  fixed-address {{ chucky_short_net }}.{{ 30 + loop.index0 }};
  option host-name "worker{{ loop.index0 }}.{{ cluster_name }}.{{ dns_zone }}";
}
{% endfor %}
```

### Set up virtual BMC or Red Fish

Two architecture options exist when the libvirt infrastrucutre components are created: **vbmc** and **redfish**.  Depending on the architecture selected a different service will be responsible to manage the VMs: **VMC** or **Red Fish**

The **support_setup.yaml** plabook contains a play that is run agains the baremental EC2 instance and is responsible of the installation and set up of the correct service for the selected architecture, namely vbmcd or sushy-tools.  

The main part of the play uses the _when_ coditional to load an independent file containing the tasks to install and set up the coresponding service:

```
- name: Set up VBMC or Red Fish
..
    - name: Set up VBMC
      include_tasks: vbmc/setup_vbmc.yaml
      when: architecture == "vbmc"

    - name: Set up sushy tools (redfish)
      include_tasks: redfish/setup_sushy.yaml
      when: architecture == "redfish"
```
The playbook that sets up the provision VM contains tasks to render the intall-config.yaml file according to the architecture selected, only one of these two tasks will run.
```
- name: Set up provision VM
...
    - name: Render install-config template for provisioning based architecture
      template:
        src: vbmc/install-config.j2
        dest: /home/kni/install-config.yaml
        owner: kni
        group: kni
        mode: 0644
      when: architecture == "vbmc"
    - name: Render install-config template for redfish based architecture
      template:
        src: redfish/install-config.j2
        dest: /home/kni/install-config.yaml
        owner: kni
        group: kni
        mode: 0644
      when: architecture == "redfish"
```

### Extracting the main release image URI 

The following task extracts the URI to quay.io, for the release image from a file hosted on an Internet server.

The URI is in the format:

```
quay.io/openshift-release-dev/ocp-release@sha256:386f4e08c48d01e0c73d294a88bb64fac3284d1d16a5b8938deb3b8699825a88
```
And is contained in the file release.txt that exists for every OCP 4 version.

```
    - name: Extract OCP {{ ocp_version }} release image URI
      set_fact:
        release_image: "{{ lookup('url','https://mirror.openshift.com/pub/openshift-v4/clients/ocp/' + ocp_version + '/release.txt') | regex_search('Pull From: (quay.io[^,]+),.*', '\\1') | list | first }}"
```
What the task does is:

* Get the remote file using the [lookup ansible pluging](https://docs.ansible.com/ansible/latest/plugins/lookup.html) that can read and return content from a variety of sources.  In this case the source is a url that is constructed using the variable **ocp_version** that contains a string like **4.9.5**:
```
lookup('url','https://mirror.openshift.com/pub/openshift-v4/clients/ocp/' + ocp_version + '/release.txt')
```
For a list of lookup plugins use the command:
```
$ ansible-doc -t lookup -l
```
For documentation on a particular lookup plugin use the command:
```
$ ansible-doc -t lookup url
```
The information returned by **lookup** is, by default, a string of comma separated values, each value representing a line in the file, so the regular expression used to extract the desired information must consider its input as a single line with commas instead of new lines to separate the lines in the original file:
```
regex_search('Pull From: (quay.io[^,]+),.*', '\\1')
```
The above regular expresion will look for the first occurence of "Pull From: " and the next part between parentheses is saved in and later returnen as output '\\1'.  The part between parentheses `(quay.io[^,]+)` captures the literal quay.io followed by any number of characters not containg a literal comma, the capture ends when a comma is found followed by any number of arbitrary characters, which are not saved and therefore not returned in the output.

The resulting output from the regular expression is a list in unicode format, so the next two filters conver it to a regular list without unicode encoding and return the first, and hopefully only element in that list.  

The output is saved to the variable release_image that should contain something like:
```
quay.io/openshift-release-dev/ocp-release@sha256:386f4e08c48d01e0c73d294a88bb64fac3284d1d16a5b8938deb3b8699825a88
```

### Dynamic MAC address assignment

The MAC addresses for worker nodes are dynamically generated using a base and a loop variable in template files dhcpd.conf.j2 and install-config.j2.

The loop.index0 variable takes values starting at 0 and is increased by one on each loop iteration, this value must be converted to an hexadecimal character from 0x00 to 0x80, that is from 0 to 128. This is done with the [python expression](https://docs.python.org/3/library/stdtypes.html#printf-style-string-formatting) **'%02x' % loop.index0**.  The %02x adds two hexadecimal numbers padding with one zero infront if only one digit is provided (0 to f):

The reason to limit the loop.index0 to 128 is because the max number is 256 (ff) but in case an additional network interface is created for bonding, double the MAC addresses are required.

```
{% for item in worker_names %}
host worker{{ loop.index0 }} {
  hardware ethernet {{ worker_chucky_mac_base }}{{ '%02x' % loop.index0 }};
  fixed-address {{ chucky_short_net }}.{{ 30 + loop.index0 }};
  option host-name "worker{{ loop.index0 }}.{{ cluster_name }}.{{ dns_zone }}";
}
{% endfor %}
```
A similar formating trick is used in terraform, for the same purposes.

## Install and set up NGINX with Ansible

The playbook **rev_proxy.yaml** can be used to install and set up the NGINX reverse proxy automatically.

A specific variable is used in this playbook:

* **ext_dns_zone**.- External DNS domain for the Openshift cluster.  This is the public domain used to access the cluster through the reverse proxy and must be resolvable by the clientes connecting to the cluster.  

     No default value is defined for this variable.

Other variables are used in the playbook and the jinja2 template used to generate the NGINX config file, but they are extracted from the terraform output variables:

* **baremetal_public_ip**.- The public IP address of EC2 metal instance
* **cluster_name**.- Cluster name that is part of the DNS domain. The complete cluster domain is **<cluster_name>.<ext_dns_zone>** for example (ocp4.redhat.com)
* **dns_zone**.- DNS base zone for the Openshift cluster

The playbook creates two self signed x509 certificates, one for the API endpoint and one for the default ingress controller.  Both are valid for the external DNS domain. 

Run the playbook with a command like:
```
$ ansible-playbook -i inventory -vvv rev_proxy.yaml -e ext_dns_zone=redhat.com
```
