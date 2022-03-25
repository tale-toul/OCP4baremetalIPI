# Set up the baremetal and Libvirt instances with Ansible

## Subscribe hosts with Red Hat
The EC2 metal host, the support and provisioning VMs all run on RHEL 8 and are subscribed with RH using an activation key, for instructions on how to create the activation key check [Creating Red Hat Customer Portal Activation Keys](https://access.redhat.com/articles/1378093)

The activation key data is stored in the file **Ansible/group_vars/all/subscription.data**.  The variables defined in this file are used by the ansible playbook.
```
subscription_activationkey: 1-234381329
subscription_org_id: 19704701
```
It is recommended to encrypt this file with ansible-vault, for example to encrypt the file with the password stored in the file vault-id use a command like:
```
$ ansible-vault encrypt --vault-id vault-id subscription.data
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

The playbook by default updates the operating system and reboots the EC2 instance if any package is updated.  Rebooting the EC2 instance may take between 10 and 20 minutes.  

To disable the OS update and instance reboot set the variable **update_OS** to false as in the example bellow.  This variable is defined in the file **Ansible/group_vars/all/general.var**. 

Run the playbook with the following command:

```
$ ansible-playbook -i inventory -vvv setup_metal.yaml --vault-id vault-id -e update_OS=false
```
###  Rebooting the host after OS update
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

This playbook shares many of the same tasks and requirements as the one defined in the file **setup_metal.yaml**:

* An [activation key](#subscribe-the-host-with-red-hat) is required to register the VMs with Red Hat.  
* An [ssh private key](#add-the-ec2-user-ssh-key) to connect to the VMs. This ssh key is the same used by the EC2 metal instance, the terraform template injects the same ssh key in all KVM VMs and EC2 instance.
* A user and password to authenticate connections to the VBMC service for every VM under its control.  In this case the same user and password is used for all VMs.  The playbook expects to get the user from the following variables, save them in a file with **.data** or **.var** extension for example **Ansible/group_vars/all/vbmc_credentials.data**:
```
vbmc_user: admin
vbmc_password: ZexUKvat]ERU
```
It is recommended to encrypt this file with ansible-vault: 
```
$ ansible-vault encrypt --vault-id vault-id vbmc_credentials.data
```
* A [pull secret](https://console.redhat.com/openshift/install/metal/user-provisioned) for the Openshift installation.  Download the pull secret and copy it to **Ansible/pull-secret**.  

### Running the playbook for libvirt VMs

The playbook is run with a command like the following, similar to the one used to set up the EC2 instance:

```
$ ansible-playbook -i inventory -vvv support_setup.yaml --vault-id vault-id 
```

### Running tasks in via a jumphost with ssh

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

The configuration files for DNS and DHCP are static and can be found in the support-files directory.  Changing this files may affect the configuration of other parts and will probably break the setup and installation process.

A group of tasks is dedicated to configure, enable and start the DNS and DHCP service in the supporting VM.

The first two task copy the configuration files for DNS and DHCP, they use the synchronize module which calls the rsync command.  
```
- name: Copy DNS and DHCP configuration files 
  synchronize:
    src: ../support-files/etc/
    dest: /etc
    use_ssh_args: yes
    owner: no
    group: no
- name: Copy DNS zone files 
  synchronize:
    src: ../support-files/var/
    dest: /var
    use_ssh_args: yes
    owner: no
    group: no
```

The rsync command will directly connect from the control host to the support host instead of using ssh as other tasks do, as a consequence the ssh tunnel through the EC2 jumphost created by other tasks is not available by default when using the synchronize module.  To solve this situation the option `use_ssh_args: yes` is used, which forces synchronize to add the ssh options defined in the vars section of the inventory file `ansible_ssh_common_args='-o ProxyJump="ec2-user@3.87.151.210"'` resulting in the following command that will make the correct ssh connection through the jump EC2 host:

```
/usr/bin/rsync --delay-updates -F --compress --archive --no-owner --no-group --rsh=/usr/bin/ssh -S none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -C -o ControlM
aster=auto -o ControlPersist=60s -o ProxyJump=\"ec2-user@3.21.134.25\" --rsync-path=sudo rsync --out-format=<<CHANGED>>%i %n%L /home/user1/OCP4baremetalIPI/support-files/var/ root@192.168.30.3:/var"
```
The next two tasks change the owner and group of DNS zone files to named:named.  In order to do this, the first taks creates a list of the files to be changed.  This task is run in the control host from where the files were copied to the remote host in the previous tasks, and the list is saved in a variable.

The next task uses a loop to change the owner and group of the files saved in the list, in the remote host.

```
- name: Get list of copied zones files
  local_action: command ls -1 ../support-files/var/named
  register: _zone_files
  become: no
- name: Change ownership of zone files
  file:
    path: /var/named/{{ item }}
    owner: named
    group: named
  loop: "{{ _zone_files.stdout_lines }}"
```
The final task enables and starts the DHCP and DNS services:
```
- name: Enable and start DNS and DHCP services
  service:
    name: "{{ item }}"
    state: started 
    enabled: yes
  loop: 
    - named
    - dhcpd
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

The MAC addresses for worker nodes are dynamically created using a base and a loop variable in template files hcpd.conf.j2 and install-config.j2.

The loop.index0 variable takes values from 0 to 16, that must be converted to an hexadecimal character 0 to a, this is done with the [python expression](https://docs.python.org/3/library/stdtypes.html#printf-style-string-formatting) **'%x' % loop.index0**:

```
{% for item in worker_names %}
host worker{{ loop.index0 }} {
  hardware ethernet {{ worker_chucky_mac_base }}{{ '%x' % loop.index0 }};
  fixed-address {{ chucky_short_net }}.{{ 30 + loop.index0 }};
  option host-name "worker{{ loop.index0 }}.{{ cluster_name }}.{{ dns_zone }}";
}
{% endfor %}
```
A similar formating trick is used in terraform, for the same purposes.
