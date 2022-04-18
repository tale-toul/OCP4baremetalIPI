Role Name
=========

This role is used to set up some support services like DNS and DHCP in the support host

Requirements
------------


Role Variables
--------------

The following variables are used in this role.  A list of commented default values is included in the file **setup_support_services/defaults/main.yml**:

* **chucky_net_addr**.- Network address for the routable chucky network, used in the DNS configuration.  Default value **192.168.30.0/24**

* **cluster_name**.- Subdomain for the whole cluster DNS name.  For example for a **cluster_name=ocp4** and a **dns_zone=tale.net** the whole cluster domain is **ocp4.tale.net**.  Used in the DNS and DHCP configuration.  Default value **ocp4**.  

* **dns_zone**.- Internal private DNS zone for the Openshift cluster.  This is not resolvable outside the virtual infrastructure.  Used in the DNS and DHCP configuration.  Default value **tale.net** 

* **master_chucky_mac_base**.- MAC address common part for the master NICs in the chucky network.  Default value 52:54:00:a9:6d:7

* **master_names**.- List of master node names. Used to specify the nodes to be configure for DNS and DHCP

* **provision_mac**.- MAC address for provision VM NIC in the routable (chucky) network.  The letters in the MACs should be in lowercase.  Default value 52:54:00:9d:41:3c

* **worker_chucky_mac_base**.- MAC address common part for the worker NICs in the chucky network.  Default value 52:54:00:a9:6d:9

* **worker_names**.- List of worker node names.  Used to specify the nodes to be configure for DNS and DHCP

Dependencies
------------

A list of other roles hosted on Galaxy should go here, plus any details in regards to parameters that may need to be set for other roles, or variables that are used from other roles.

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: username.rolename, x: 42 }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
