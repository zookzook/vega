#!/usr/bin/env bash

needs_initiate=1

# start the mongod servers of the replica set
for i in $(seq 1 3); do
  mkdir -p tmp/db$i
  pid="$(cat tmp/db$i/mongod.lock 2>/dev/null)"

  if [ $? -ne 0 -a -z "$pid" ]; then
    # >&2 echo "starting mongo server $i"
    port=$((27016 + i))
    mongod --fork --dbpath tmp/db$i --logpath tmp/db$i/log --port $port --bind_ip 127.0.0.1 --replSet vega_set &>/dev/null

    if [ $? -ne 0 ]; then
      . ./stop_mongo.bash
      >&2 echo "failed to start mongo servers..."
      exit 1
    fi

    >&2 echo "mongo server $i started"
  else
    needs_initiate=0
  fi
done

# initiate the replica set

>&2 echo "needs initiate: $needs_initiate"
if [[ $needs_initiate -eq 1 ]]; then
  >&2 echo "initiating"

  host1='"127.0.0.1:27017"'
  host2='"127.0.0.1:27018"'
  host3='"127.0.0.1:27019"'
  members="[{_id: 0, host: $host1}, {_id: 1, host: $host2}, {_id: 2, host: $host3}]"
  mongo --quiet --port 27017 --eval "JSON.stringify(rs.initiate({_id: \"vega_set\", members: $members}))" >/dev/null

  if [ $? -ne 0 ]; then
    >&2 echo "failed to configure replica set"
    exit 1
  fi

  >&2 echo "initiated"
fi

repl_set_url='mongodb://localhost:27017,localhost:27018,localhost:27019/vega?replicaSet=vega_set'

>&2 echo "replica set election"
mongo --port 27017 --quiet --eval 'typeof db.createUser === "function"' >tmp/over24
if [ $? -ne 0 ]; then
  >&2 echo "failed while waiting for replica set election"
  exit 1
else
  >&2 echo "done"
  >&2 echo "creating collections"
  mongo --host $repl_set_url --quiet --eval "db.createCollection('users')" &>/dev/null
  mongo --host $repl_set_url --quiet --eval "db.createCollection('boards')" &>/dev/null
  mongo --host $repl_set_url --quiet --eval "db.createCollection('cards')" &>/dev/null
  mongo --host $repl_set_url --quiet --eval "db.createCollection('issues')" &>/dev/null
  >&2 echo "done"
fi

exit 0
