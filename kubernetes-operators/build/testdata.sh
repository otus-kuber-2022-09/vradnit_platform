#!/bin/bash

action="$1"
password="$2"


export MYSQLPOD=$(kubectl get pods -l app=mysql-instance -o jsonpath="{.items[*].metadata.name}")

case $action in
upload)
    kubectl exec -it $MYSQLPOD -- mysql -u root -p${password} -e "CREATE TABLE test ( id smallint unsigned not null auto_increment, name varchar(20) not null, constraint pk_example primary key(id) );" otus-database
    kubectl exec -it $MYSQLPOD -- mysql -p${password} -e "INSERT INTO test ( id, name ) VALUES (null, 'some data-1' );" otus-database
    kubectl exec -it $MYSQLPOD -- mysql -p${password} -e "INSERT INTO test ( id, name ) VALUES (null, 'some data-2' );" otus-database
    kubectl exec -it $MYSQLPOD -- mysql -p${password} -e "INSERT INTO test ( id, name ) VALUES (null, 'some data-3' );" otus-database
    kubectl exec -it $MYSQLPOD -- mysql -p${password} -e "INSERT INTO test ( id, name ) VALUES (null, 'some data-4' );" otus-database
    ;;
show)
    kubectl exec -it $MYSQLPOD -- mysql -p${password} -e "select * from test" otus-database
    ;;
*)
    kubectl exec -it $MYSQLPOD -- mysql -p${password} -e "select * from test" otus-database
    ;;
esac


