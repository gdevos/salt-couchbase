include:
  - couchbase.common

{% set couchbase_server = pillar.get('couchbase_server', {}) -%}
{% set couchbase_version = couchbase_server.get('version', '2.5.1') -%}
{% set couchbase_username = couchbase_server.get('couchbase_username', 'Administrator') -%}
{% set couchbase_password = couchbase_server.get('couchbase_password', 'password') -%}
{% set couchbase_admin_port = couchbase_server.get('admin_port', '8091') -%}


{%- set node_mem_usage = (salt['grains.get']('mem_total', '') * (4 / 5))|round|int  %}

## Discover Other Couchbase Nodes
## This is stupid hacky, but we have to do it to maintain scope outside of the loop vars.
## so, we first load up a list with cluster members, then push the 127.0.0.1 ip to the list
## and pull the first IP from the cluster_members list.  If the cluster_members list's first element
## is 127.0.0.1, it's safe to assume this is the first node in the cluster.

{%- set cluster_members = [] -%}

{%- set util_compound_string = 'G@ec2_roles:*couchbase* and G@ec2_environment:' +  ','.join(grains.get('ec2_environment','')) + ' and G@ec2_apps:*' + ''.join(grains.get('ec2_apps','')) + '*' %}
{%- set server_list = salt['publish.publish']( '%s' % util_compound_string, 'network.ip_addrs', 'eth0', 'compound') -%}

{% for server,ips in server_list.iteritems() %}
{% if server != salt['grains.get']('localhost')  %}
{% do cluster_members.append(ips[0]) %}
{# debug
test-{{ server }}-{{ ips[0] }}:
  cmd.run:
    - name: echo {{ ips[0] }}
#}
{% endif %}
{% endfor %}

{% do cluster_members.append('127.0.0.1') %}

{% set cluster_member = cluster_members[0] %}
test-{{ cluster_member }}:
  cmd.run:
    - name: "echo cluster member {{ cluster_member }}"


couchbase-src-salt:
  file.directory:
    - name: /src-salt/couchbase
    - user: root
    - group: users
    - makedirs: True

couchbase-requirements:
  pkg:
    - latest
    - names:
      - curl
      - wget

couchbase-get:
  cmd.run:
    - name: 'curl -o /src-salt/couchbase/couchbase-server-enterprise_{{ couchbase_version }}_x86_64.deb http://packages.couchbase.com/releases/2.5.1/couchbase-server-enterprise_{{ couchbase_version }}_x86_64.deb'
    - unless: 'test -f /src-salt/couchbase/couchbase-server-enterprise_{{ couchbase_version }}_x86_64.deb'
    - require:
      - file: couchbase-src-salt
      - pkg: couchbase-requirements

couchbase-install:
  cmd.wait:
    - name: dpkg -i /src-salt/couchbase/couchbase-server-enterprise_{{ couchbase_version }}_x86_64.deb
    - cwd: /src-salt/couchbase
    - require:
      - cmd: couchbase-get
      - sls: couchbase.common
    - watch:
      - cmd: couchbase-get

couchbase-server:
  service.running:
    - require:
      - cmd: couchbase-install

test:
  cmd.run:
    - name: echo "{{ cluster_member }}" >> /tmp/mem

{%- if cluster_member == '127.0.0.1' %}
couchbase-cluster-init:
  cmd.run:
    - name: 'sleep 10s; /opt/couchbase/bin/couchbase-cli cluster-init -c 127.0.0.1:{{ couchbase_admin_port }} --cluster-init-port={{ couchbase_admin_port }} --cluster-init-username={{ couchbase_username }} --cluster-init-password={{ couchbase_password }} --cluster-init-ramsize={{ node_mem_usage }} -u {{ couchbase_username }} -p {{ couchbase_password }}'
    - unless: sleep 10 && /opt/couchbase/bin/couchbase-cli server-list -c 127.0.0.1:{{ couchbase_admin_port }} -u {{ couchbase_username }} -p {{ couchbase_password }} | grep '127.0.0.1' | grep "healthy active"
    - require:
        - service: couchbase-server

couchbase-cluster-add:
  cmd.run:
    - name: 'sleep 10s; /opt/couchbase/bin/couchbase-cli server-add -c 127.0.0.1:{{ couchbase_admin_port }} -u {{ couchbase_username }} -p {{ couchbase_password }} --server-add={{ salt['grains.get']('ip_interfaces:eth0')[0] }}:{{ couchbase_admin_port }} --server-add-username={{ couchbase_username }} --server-add-password={{ couchbase_password }}'
    - unless: sleep 10 && /opt/couchbase/bin/couchbase-cli server-info -c 127.0.0.1:{{ couchbase_admin_port }}  -u {{ couchbase_username }} -p {{ couchbase_password }} | grep clusterMembership | grep active
    - require:
        - service: couchbase-server
    - watch_in:
        - cmd: couchbase-cluster-rebalance

couchbase-cluster-bucket:
  cmd.run:
    - name: 'sleep 10s; /opt/couchbase/bin/couchbase-cli bucket-create -c 127.0.0.1:{{ couchbase_admin_port }} --bucket=default --bucket-type=memcached --bucket-ramsize={{ node_mem_usage }} --bucket-replica=0 -u {{ couchbase_username }} -p {{ couchbase_password }}'
    - unless: sleep 10 && /opt/couchbase/bin/couchbase-cli bucket-list -c 127.0.0.1:{{ couchbase_admin_port }} -u {{ couchbase_username }} -p {{ couchbase_password }}
    - require:
        - service: couchbase-server
{% else %}
couchbase-cluster-init:
  cmd.run:
    - name: 'sleep 10s; /opt/couchbase/bin/couchbase-cli cluster-init -c {{ salt['grains.get']('ip_interfaces:eth0')[0] }}:{{ couchbase_admin_port }} --cluster-init-port={{ couchbase_admin_port }} --cluster-init-username={{ couchbase_username }} --cluster-init-password={{ couchbase_password }} --cluster-init-ramsize={{ node_mem_usage }} -u {{ couchbase_username }} -p {{ couchbase_password }}'
    - unless: sleep 10 && /opt/couchbase/bin/couchbase-cli server-list -c {{ cluster_member }}:{{ couchbase_admin_port }} -u {{ couchbase_username }} -p {{ couchbase_password }} | grep "healthy active" | grep '{{ cluster_member }}'
    - require:
        - service: couchbase-server

couchbase-cluster-add:
  cmd.run:
    - name: 'sleep 10s; /opt/couchbase/bin/couchbase-cli server-add -c {{ cluster_member }}:{{ couchbase_admin_port }} -u {{ couchbase_username }} -p {{ couchbase_password }} --server-add={{ salt['grains.get']('ip_interfaces:eth0')[0] }}:{{ couchbase_admin_port }} --server-add-username={{ couchbase_username }} --server-add-password={{ couchbase_password }}'
    - unless: sleep 10 && /opt/couchbase/bin/couchbase-cli server-list -c {{ cluster_member }}:{{ couchbase_admin_port }}  -u {{ couchbase_username }} -p {{ couchbase_password }} | grep '{{ salt['grains.get']('ip_interfaces:eth0')[0] }}'
    - require:
        - service: couchbase-server

couchbase-cluster-bucket:
  cmd.run:
    - name: 'sleep 10s; /opt/couchbase/bin/couchbase-cli bucket-create -c 127.0.0.1:{{ couchbase_admin_port }} --bucket=default --bucket-type=memcached --bucket-ramsize={{ node_mem_usage }} --bucket-replica=0 -u {{ couchbase_username }} -p {{ couchbase_password }}'
    - unless: sleep 10 && /opt/couchbase/bin/couchbase-cli bucket-list -c {{ cluster_member }}:{{ couchbase_admin_port }} -u {{ couchbase_username }} -p {{ couchbase_password }} | grep bucketType
    - require:
        - service: couchbase-server
{% endif %}


couchbase-cluster-rebalance:
  cmd.wait:
    - name: 'sleep 10s; /opt/couchbase/bin/couchbase-cli rebalance -c {{ cluster_member }}:{{ couchbase_admin_port }}  -u {{ couchbase_username }} -p {{ couchbase_password }}'
    - onlyif: /opt/couchbase/bin/couchbase-cli rebalance-status -c {{ cluster_member }}:{{ couchbase_admin_port }} -u {{ couchbase_username }} -p {{ couchbase_password }} | grep None
    - watch:
        - cmd: couchbase-cluster-add
    - require:
        - service: couchbase-server
        - cmd: couchbase-cluster-bucket

