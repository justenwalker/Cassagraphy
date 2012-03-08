Cassagraphy
=================

A set of ruby scripts that can convert a yaml cassandra schema definition
into a graphical representation.

It can also generate a basic yaml file by inspecting a cassandra instance which can give you a head-start generating a yaml for your own schema.

Currently it only supports html output.

Running
------------

    ruby cassagraphy.rb "/path/to/yaml"

Dependencies
------------

cassandra (0.12.2)
