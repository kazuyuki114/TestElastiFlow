#!/bin/bash

echo "Waiting for ClickHouse to be ready..."
until clickhouse-client --query "SELECT 1" &>/dev/null; do
  echo "ClickHouse is unavailable - sleeping"
  sleep 2
done

# Create user from environment variables (skip if access management is not enabled)
clickhouse-client --host clickhouse --query "
CREATE USER IF NOT EXISTS ${CLICKHOUSE_USER} IDENTIFIED BY '${CLICKHOUSE_PASSWORD}';
GRANT ALL ON *.* TO ${CLICKHOUSE_USER} WITH GRANT OPTION;
" 2>/dev/null || echo "Skipping user creation (access management may not be enabled)"

echo "Creating database and tables"
# Create database
clickhouse-client --query "CREATE DATABASE IF NOT EXISTS KafkaEngine"

echo "Database and tables created successfully!"
clickhouse-client --query "CREATE TABLE IF NOT EXISTS KafkaEngine.netflow_logs
(
    timestamp DateTime DEFAULT now(),
    raw_body String  
)
ENGINE = MergeTree()
ORDER BY timestamp;"


clickhouse-client --query "CREATE TABLE KafkaEngine.netflow_logs_queue
(
    line String 
)
ENGINE = Kafka
SETTINGS kafka_broker_list = 'kafka:9092',
         kafka_topic_list = 'elastiflow-flow-codex-1.0',
         kafka_group_name = 'clickhouse_flow_consumer',
         kafka_format = 'JSONAsString';"

clickhouse-client --query "CREATE MATERIALIZED VIEW IF NOT EXISTS KafkaEngine.netflow_logs_mv TO KafkaEngine.netflow_logs AS
SELECT
    now() as timestamp,
    line as raw_body
FROM KafkaEngine.netflow_logs_queue;" 


clickhouse-client --query "CREATE TABLE IF NOT EXISTS KafkaEngine.snmp_logs
(
    timestamp DateTime DEFAULT now(),
    raw_body String  
)
ENGINE = MergeTree()
ORDER BY timestamp;"


clickhouse-client --query "CREATE TABLE KafkaEngine.snmp_logs_queue
(
    line String 
)
ENGINE = Kafka
SETTINGS kafka_broker_list = 'kafka:9092',
         kafka_topic_list = 'elastiflow-snmp-codex-1.0',
         kafka_group_name = 'clickhouse_snmp_consumer',
         kafka_format = 'JSONAsString';"

clickhouse-client --query "CREATE MATERIALIZED VIEW IF NOT EXISTS KafkaEngine.snmp_logs_mv TO KafkaEngine.snmp_logs AS
SELECT
    now() as timestamp,
    line as raw_body
FROM KafkaEngine.snmp_logs_queue;" 


clickhouse-client --query "CREATE TABLE IF NOT EXISTS KafkaEngine.trap_logs
(
    timestamp DateTime DEFAULT now(),
    raw_body String  
)
ENGINE = MergeTree()
ORDER BY timestamp;"


clickhouse-client --query "CREATE TABLE KafkaEngine.trap_logs_queue
(
    line String 
)
ENGINE = Kafka
SETTINGS kafka_broker_list = 'kafka:9092',
         kafka_topic_list = 'elastiflow-trap-codex-1.0',
         kafka_group_name = 'clickhouse_trap_consumer',
         kafka_format = 'JSONAsString';"

clickhouse-client --query "CREATE MATERIALIZED VIEW IF NOT EXISTS KafkaEngine.trap_logs_mv TO KafkaEngine.trap_logs AS
SELECT
    now() as timestamp,
    line as raw_body
FROM KafkaEngine.trap_logs_queue;" 

touch /tmp/clickhouse-init-done
echo "ClickHouse initialization complete!"