Salt State for Couchbase
========================

Salt state for installing and config management of Couchbase servers.

ICYMI: Salt is a configuration management tool. http://saltstack.com/  
Couchbase is a NoSQL key-value and document database with memcached and couchdb roots. http://www.couchbase.com/

The start files here were cloned from https://github.com/allanparsons/salt-couchbase

The state does not add extra nodes automatically to the cluster yet, WiP. Use the CLI or GUI commands to add nodes.
Usage
-----

Copy the directories to your pillar and states directories in your Salt set up.   

Modify the pillar/couchbase/server.sls to suit your environment.

Edit /etc/salt/grains and add the couchbase role and set the environment.
```yaml
roles:
  - couchbase
environment: production
```

Run once: salt 'couchbase-servers*' state.apply couchbase.server   
Or add it to your top.sls of course.

