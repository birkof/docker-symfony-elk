FROM java:8

MAINTAINER Daniel STANCU <birkof@birkof.ro>

# Default versions
ENV ELASTICSEARCH_VERSION 1.4 # 2.x
ENV LOGSTASH_VERSION 1.5 # 2.1
ENV KIBANA_VERSION 4.1.2 # 4.3.1

# Update system repositories
RUN apt-get -y update

# Install apt-utils
RUN apt-get -y --force-yes install apt-utils

# Upgrade system
RUN apt-get -y dist-upgrade

RUN apt-get install --no-install-recommends -y supervisor

# Elasticsearch
RUN \
    apt-key adv --keyserver pool.sks-keyservers.net --recv-keys 46095ACC8548582C1A2699A9D27D666CD88E42B4 \
    && if ! grep "elasticsearch" /etc/apt/sources.list; then echo "deb http://packages.elastic.co/elasticsearch/2.x/debian stable main" >> /etc/apt/sources.list;fi \
    && if ! grep "logstash" /etc/apt/sources.list; then echo "deb http://packages.elastic.co/logstash/2.1/debian stable main" >> /etc/apt/sources.list;fi \
    && apt-get update

RUN \
    apt-get install --no-install-recommends -y elasticsearch \
    && sed -i 's/^# cluster.name:.*$/cluster.name: symfony/g' /etc/elasticsearch/elasticsearch.yml \
    && sed -i 's/^# path.data:.*$/path.data: \/tmp\/elasticsearch/g' /etc/elasticsearch/elasticsearch.yml \
    && sed -i 's/^#MAX_MAP_COUNT=.*$/MAX_MAP_COUNT=/g' /etc/default/elasticsearch
ADD supervisor/conf.d/elasticsearch.conf /etc/supervisor/conf.d/elasticsearch.conf

# Logstash
RUN apt-get install --no-install-recommends -y logstash
ADD supervisor/conf.d/logstash.conf /etc/supervisor/conf.d/logstash.conf

# Configs & patterns
ADD logstash/conf.d /etc/logstash/conf.d
ADD logstash/patterns /opt/logstash/patterns

# Logstash plugins
RUN /opt/logstash/bin/plugin install logstash-filter-translate

# Kibana
RUN \
    curl -s https://download.elastic.co/kibana/kibana/kibana-4.3.1-linux-x64.tar.gz | tar -C /opt -xz \
    && ln -s /opt/kibana-4.3.1-linux-x64 /opt/kibana
ADD supervisor/conf.d/kibana.conf /etc/supervisor/conf.d/kibana.conf

# Clean up the mess
RUN apt-get remove --purge -y \
        apt-utils \
    && apt-get autoclean \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Exposed port/s (web interface)
EXPOSE 5601 9200

# Environment variables
ENV PATH /opt/logstash/bin:$PATH

CMD [ "/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf" ]
