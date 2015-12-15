#
# couchbase pillar data
#

{% set environment = grains.get('environment') %}

{#######################################################################
################ PRODUCTION VALUES                      ################
#######################################################################}
{%- if environment == 'production' %}
  {%- set couchbase_username = 'Administrator' %}
  {%- set couchbase_password = 'zzz1' %}

{#######################################################################
################ DEVELOPMENT VALUES                     ################
#######################################################################}
{%- elif environment == 'development' %}
  {%- set couchbase_username = 'Administrator' %}
  {%- set couchbase_password = 'zzz2' %}

{#######################################################################
################ QA VALUES                              ################
#######################################################################}
{%- elif  environment == 'qa' %}
  {%- set couchbase_username = 'Administrator' %}
  {%- set couchbase_password = 'zzz3' %}

{#######################################################################
################ STAGING VALUES                         ################
#######################################################################}
{%- elif environment == 'staging' %}
  {%- set couchbase_username = 'Administrator' %}
  {%- set couchbase_password = 'zzz4' %}

{#######################################################################
################ DEFAULT VALUES                         ################
#######################################################################}
{% else %}

{% endif %}

couchbase_server:
  version: 4.0.0
  edition: couchbase-server-community
  admin_port: 8091
  couchbase_username: {{ couchbase_username }}
  couchbase_password: {{ couchbase_password }}
