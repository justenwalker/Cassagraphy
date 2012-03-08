Cassagraphy
=================

A set of ruby scripts that can convert a yaml cassandra schema definition
into a graphical representation.

It can also generate a basic yaml file by inspecting a cassandra instance which can give you a head-start generating a yaml for your own schema.

Currently it only supports html output.

Running
------------

To generate a yaml file from an existing Cassandra instance:

    ruby cassagraphy.rb generate "localhost:9160" "schema.yaml"

To generate the graphical representation of the yaml file:

    ruby cassagraphy.rb render "schema.yaml" "schema.html"

Dependencies
------------

cassandra (0.12.2)
