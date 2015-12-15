#include:
#  - build_tools

{% if grains['osfinger'] == 'Ubuntu-14.04' %}
  {% set couchbase_source_list = 'couchbase-ubuntu1404.list' %}
{% elif grains['osfinger'] == 'Ubuntu-12.05' %}
  {% set couchbase_source_list = 'couchbase-ubuntu1204.list' %}
{% elif grains['osfinger'] == 'Ubuntu-10.04 ' %}
  {% set couchbase_source_list = 'couchbase-ubuntu1004.list' %}
{% endif %}

couchbase-dependencies:
    pkg.installed:
     - pkgs:
        - libevent-dev
        - wget

couchbase-pkg:
  pkg.installed:
    - pkgs:
        - libcouchbase2-libevent
        - libcouchbase-dev
        - libcouchbase2-core
    - refresh: True
    - require:
        - pkg: couchbase-dependencies

/etc/apt/sources.list.d/couchbase.list:
  file.managed:
    - source: salt://couchbase/files/{{ couchbase_source_list }}
    #- source: http://packages.couchbase.com/ubuntu/{{ couchbase_source_list }}
    - user: root
    - group: root
    - mode: 644
  cmd.wait:
    - name: "wget -qO- http://packages.couchbase.com/ubuntu/couchbase.key | sudo apt-key add -"
    - watch:
       - file: /etc/apt/sources.list.d/couchbase.list
    - require:
       - pkg: couchbase-dependencies
    - require_in:
       - pkg: couchbase-pkg
