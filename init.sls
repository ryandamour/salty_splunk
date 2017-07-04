{% import 'splunk/files/variables.jinja' as variables with context %}
/usr/local/src/splunk-6.6.0-1c4f3bbe1aea-linux-2.6-x86_64.rpm:
  file.managed:
    - source: salt://splunk/files/splunk-6.6.0-1c4f3bbe1aea-linux-2.6-x86_64.rpm
    - user: root
    - group: root
    - unless:
      - ls /opt/splunk
      - ls /usr/local/src/splunk-6.6.0-1c4f3bbe1aea-linux-2.6-x86_64.rpm

execute_splunk_rpm:
  cmd.run:
    - name: rpm -Uvh /usr/local/src/splunk-6.6.0-1c4f3bbe1aea-linux-2.6-x86_64.rpm
    - unless: ls /opt/splunk

start_splunk_on_boot:
  cmd.run:
    - name: /opt/splunk/bin/splunk enable boot-start -user splunk --accept-license
    - onlyif:
      - ls /opt/splunk

splunk:
  service.running: []

splunk_cleanup:
  cmd.run:
    - name: rm -f /usr/local/src/splunk-6.6.0-1c4f3bbe1aea-linux-2.6-x86_64.rpm
    - onlyif:
      - ls /opt/splunk

{% if grains['id'].startswith('splunk-index') %}

{% for i in '9887','9997','8089','8000' %}
firewall_indexer_modify_{{i}}:
  cmd.run:
    - name: firewall-cmd --permanent --add-port={{i}}/tcp && firewall-cmd --reload
{% endfor %}

enable_index_cluster:
  cmd.run:
    - name: /opt/splunk/bin/splunk edit cluster-config -mode slave -master_uri https://{{ variables.master_ip }}:8089 -replication_port 9887 -secret {{ variables.cluster_secret }} -cluster_label {{ variables.index_cluster_label }} -auth admin:changeme
    - user: splunk 

restart_indexer:
  cmd.run:
    - name: systemctl restart splunk
 
{% endif %}

{% if grains['id'].startswith('splunk-master') %}

{% for i in '8000','8089' %}
firewall_master_modify_{{i}}:
  cmd.run:
    - name: firewall-cmd --permanent --add-port={{i}}/tcp && firewall-cmd --reload
{% endfor %}

enable_master_node:
  cmd.run:
    - name: /opt/splunk/bin/splunk edit cluster-config -mode master -replication_factor {{ variables.index_rep_factor }} -search_factor {{ variables.index_search_factor }} -secret {{ variables.cluster_secret }} -cluster_label {{ variables.index_cluster_label }}
    - user: splunk

restart_master:
  cmd.run:
    - name: systemctl restart splunk

{% endif %}

{% if grains['id'].startswith('splunk-deployer') %}

{% for i in '8000','8089' %}
firewall_master_modify_{{i}}:
  cmd.run:
    - name: firewall-cmd --permanent --add-port={{i}}/tcp && firewall-cmd --reload
{% endfor %}

/opt/splunk/etc/system/local/server.conf:
  file.append:
    - text:
      - [shclustering]
      - pass4SymmKey = {{ variables.cluster_secret }} 
      - shcluster_label = {{ variables.sh_cluster_label }}

restart_deployer:
  cmd.run:
    - name: systemctl restart splunk 

{% endif %}

{% if grains['id'].startswith('splunk-searchhead') %}

{% for i in '8000','8089','6667' %}
firewall_search_head_modify_{{i}}:
  cmd.run:
    - name: firewall-cmd --permanent --add-port={{i}}/tcp && firewall-cmd --reload
{% endfor %}

{% endif %}

{% if grains['id'].startswith('splunk-searchhead1') %}
init_searchhead1:
  cmd.run:
    - name: /opt/splunk/bin/splunk init shcluster-config -auth admin:changeme -mgmt_uri https://{{ variables.search_head_1_ip }}:{{ variables.deployer_port }} -replication_port 6667 -replication_factor {{ variables.rep_factor }} -conf_deploy_fetch_url https://{{ variables.deployer_ip }}:8089 -secret {{ variables.cluster_secret }} -shcluster_label {{ variables.sh_cluster_label }}
    - user: splunk

restart_searchhead1:
  cmd.run:
    - name: systemctl restart splunk

sh1_to_index_cluster:
  cmd.run:
    - name: /opt/splunk/bin/splunk edit cluster-config -mode searchhead -master_uri https://{{ variables.master_ip }}:8089 -secret {{ variables.cluster_secret }} -auth admin:changeme
    - user: splunk


{% endif %}

{% if grains['id'].startswith('splunk-searchhead2') %}
init_searchhead2:
  cmd.run:
    - name: /opt/splunk/bin/splunk init shcluster-config -auth admin:changeme -mgmt_uri https://{{ variables.search_head_2_ip }}:{{ variables.deployer_port }} -replication_port 6667 -replication_factor {{ variables.rep_factor }} -conf_deploy_fetch_url https://{{ variables.deployer_ip }}:8089 -secret {{ variables.cluster_secret }} -shcluster_label {{ variables.sh_cluster_label }}
    - user: splunk

restart_searchhead2:
  cmd.run:
    - name: systemctl restart splunk

sh2_to_index_cluster:
  cmd.run:
    - name: /opt/splunk/bin/splunk edit cluster-config -mode searchhead -master_uri https://{{ variables.master_ip }}:8089 -secret {{ variables.cluster_secret }} -auth admin:changeme
    - user: splunk

{% endif %}

{% if grains['id'].startswith('splunk-searchhead3') %}

init_searchhead3:
  cmd.run:
    - name: /opt/splunk/bin/splunk init shcluster-config -auth admin:changeme -mgmt_uri https://{{ variables.search_head_3_ip }}:{{ variables.deployer_port }} -replication_port 6667 -replication_factor {{ variables.rep_factor }} -conf_deploy_fetch_url https://{{ variables.deployer_ip }}:8089 -secret {{ variables.cluster_secret }} -shcluster_label {{ variables.sh_cluster_label }}
    - user: splunk

elect_captain:
  cmd.run:
    - name: /opt/splunk/bin/splunk bootstrap shcluster-captain -servers_list "https://{{ variables.search_head_1_ip }}:8089, https://{{variables.search_head_2_ip }}:8089, https://{{ variables.search_head_3_ip }}:8089" -auth admin:changeme 

restart_searchhead3:
  cmd.run:
    - name: systemctl restart splunk

sh3_to_index_cluster:
  cmd.run:
    - name: /opt/splunk/bin/splunk edit cluster-config -mode searchhead -master_uri https://{{ variables.master_ip }}:8089 -secret {{ variables.cluster_secret }} -auth admin:changeme 
    - user: splunk

{% endif %}
