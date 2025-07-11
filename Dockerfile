FROM apache/airflow:2.10.5


RUN pip install --no-cache-dir apache-airflow-providers-apache-spark 
RUN pip install --no-cache-dir apache-airflow-providers-cncf-kubernetes>=6.0.0
RUN pip install --no-cache-dir apache-airflow-providers-amazon>=3.3.0
USER airflow
