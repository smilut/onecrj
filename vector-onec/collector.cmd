SET onec_logs_path=c:\logs
SET onec_logs_server=http://192.168.229.133:8123
SET onec_logs_api_ip_port=0.0.0.0:8686
SET onec_logs_metric_ip_port=0.0.0.0:9598
SET onec_logs_user=agent
SET onec_logs_password=qwerty
SET onec_logs_database=log_storage
SET onec_logs_table_logs=onec_log
SET onec_logs_table_errors=onec_log_error
SET onec_logs_table_collector=collector_log
SET onec_logs_debug=false

C:\Progra~1\Vector\bin\vector --config c:\home\vector-onec\vector.toml
