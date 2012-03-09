require 'rubygems'
require "yaml"
require "cassandra"
require "cassagraphy/toposort.rb"

module Model
  def self.class2type(c)
    if( /.*[.](.*)Type/.match(c) )
      return $1
    end
    return c
  end
  def self.generate(servers,outfile)
    client = Cassandra.new('system',servers)
    m = {}
    cluster = client.cluster_name
    m[cluster] = {}
    keyspaces = client.keyspaces
    client.disconnect!
    keyspaces.each do |keyspace|
      client = Cassandra.new(keyspace,servers)
      m[cluster][keyspace] = {}
      cfs = client.column_families.each_pair do |cfname,cfdef|
        m[cluster][keyspace][cfname] = {}
	cf = m[cluster][keyspace][cfname] 
        cf['key'] = 'Row Key'
        cf['key-type'] = Model::class2type(cfdef.key_validation_class)
	if cfdef.column_type == "Super"
          cf['supercolumns']  = {}
          scf = cf['supercolumns']
          scf['key'] = 'Super Column Key'
          scf['key-type'] = Model::class2type(cfdef.comparator_type)
          scf['repeat'] = 'true'
          scf['columns'] = {}
          cols = scf['columns']
          cols['name-type'] = Model::class2type(cfdef.subcomparator_type)
          cols['value-type'] = Model::class2type(cfdef.default_validation_class)
          cols['column'] = [ { 'name' => 'Column Name', 'value' => 'Column Value', 'repeat' => 'true'} ]
	else
          cf['columns']  = {}
          cf['columns']['name-type'] = Model::class2type(cfdef.comparator_type)
          cf['columns']['value-type'] = Model::class2type(cfdef.default_validation_class)
          cf['columns']['column'] = [ { 'name' => 'Column Name', 'value' => 'Column Value', 'repeat' => 'true'} ]
	end
      end
      client.disconnect!
    end
    File.open(outfile,'w') do |out|
      YAML::dump(m,out)
    end
    return m
  end
  def self.getDefault(hash,key,default)
    if hash != nil
      hash.key?(key) ? hash[key] : default
    else
      default
    end
  end
  class Column
    def initialize( column, columndef )
      @columndef = columndef
      @nametype  = @columndef.nametype
      @valuetype = @columndef.valuetype
      @name      = Model::getDefault(column,'name'     , @nametype)
      @value     = Model::getDefault(column,'value'    , @valuetype)
      @repeat    = Model::getDefault(column,'repeat'   , false)
      @const     = Model::getDefault(column,'const'    , true)
      @optional  = Model::getDefault(column,'optional' , false)
    end
    def name
      if( @name == @nametype)
        return @nametype
      elsif ( @const and not @repeat )
        return "'#{@name}'"
      else
      	return "#{@name}:#{@nametype}"
      end
    end
    def value
      if( @value == @valuetype)
        return @valuetype
      else
      	return "#{@value}:#{@valuetype}"
      end
    end
    def constant?
      @const
    end
    def repeat?
    	@repeat
    end
    def optional?
      @optional
    end
  end
  class ColumnDef
    def initialize( columndef )
      @columndef = columndef
      @nametype  = Model::getDefault(columndef,'name-type','Bytes')
      @valuetype = Model::getDefault(columndef,'value-type','Bytes')
      @columns = []
      columndef['column'].each do |col|
      	@columns += [Column.new(col,self)]
      end
    end
    def merge( cd )
      newcdef = cd.columndef.merge(@columndef)
      newcdef['column'] = @columndef['column'] + cd.columndef['column']
      ColumnDef.new(newcdef)
    end
    def columns
    	@columns
    end
    def valuetype
    	return @valuetype
    end
    def nametype
    	return @nametype
    end
    def columndef
      @cdef
    end
    def clone
      return ColumnDef.new(@columndef)
    end
  end

  class SuperColumnDef
    def initialize( scdef )
      @columndef = scdef
      @keytype = Model::getDefault(@columndef,'key-type','Bytes')
      @key     = Model::getDefault(@columndef,'key',@keytype)
      @columns = ColumnDef.new(@columndef['columns'])
      @repeat  = Model::getDefault(@columndef,'repeat',false)
      @optional  = Model::getDefault(@columndef,'optional',false)
    end
    def merge( scdef )
      SuperColumnDef.new(@columndef.merge(scdef.columndef))
    end
    def repeat?
    	@repeat
    end
    def key
      if @keytype == @key
        return @keytype
      else
        return "#{@key}:#{@keytype}"
      end
    end
    def optional?
      @optional
    end
    def columns
    	@columns
    end
    def columndef
      @columndef
    end
    def clone
      SuperColumnDef.new(@columndef)
    end
  end

  class ColumnFamily
    def initialize( keyspace, name, cfDef )
      @keyspace = keyspace
      @name = name
      @extends = []
      @keytype  = Model::getDefault(cfDef,'key-type','Bytes')
      @key =  Model::getDefault(cfDef,'key',@keytype) 
      @supercf = cfDef.key?('supercolumns')
      if @supercf
        @columns = SuperColumnDef.new(cfDef['supercolumns'])
      elsif cfDef.key?('columns')
        @columns = ColumnDef.new(cfDef['columns'])
      elsif cfDef.key?('extends')
        @columns = nil
        @extends = cfDef['extends']
      end
      model.register(self)
    end
    def load()
      @extends.each do |name|
        cf = getCfFromModel(name)
	if @keytype == 'Bytes'
	  @keytype = cf.keytype
	end
	if @key == 'Bytes'
	  @key = cf.key
	end
        if( @columns == nil )
          @columns = cf.columns.clone
        else
          @columns = @columns.merge(cf.columns)
        end
      end
    end
    def key
    	@key
    end
    def keytype
	@keytype
    end
    def key
    	if @key == @keytype
		return @keytype
	else
		return "#{@key}:#{@keytype}"
	end
    end
    def super?
    	@supercf
    end
    def getCfFromModel(name)
      model.getCfByFullName(name)
    end
    def extends
      @extends
    end
    def extend!(extends)
      @extends = extends
    end
    def model
      @keyspace.cluster.model
    end
    def cluster
      @keyspace.cluster
    end
    def columns
      @columns
    end
    def keyspace
      @keyspace
    end
    def name
      @name
    end
  end

  class Keyspace
    def initialize( cluster, name, columnfamilies )
      @cluster = cluster
      @name = name
      @cfs  = {}
      columnfamilies.each_pair do |cfname,cfDef|
        @cfs[cfname] = ColumnFamily.new(self,cfname,cfDef)
      end
    end
    def columnfamilies
    	@cfs
    end
    def getCf(name)
      @cfs[name]
    end
    def cluster
      @cluster
    end
    def name
      @name
    end
  end

  class Cluster
    def initialize(model, name,keyspaces)
      #puts "Cluster: " + name
      @model = model
      @name = name
      @keyspaces = {}
      keyspaces.each_pair do |ksname,columnfamilies|
        addKeyspace( ksname, columnfamilies )
      end
    end
    def addKeyspace(name, columnfamilies)
      @keyspaces[name] = Keyspace.new( self, name, columnfamilies )
    end
    def getKeyspace(name)
      @keyspaces[name]
    end
    def keyspaces
    	@keyspaces
    end
    def model
      @model
    end
    def name
      @name
    end
  end

  class CassandraModel
    def initialize(yamlfile)
      @cfs = {}
      c = YAML::load_file(yamlfile)
      @clusters = {}
      c.each_pair do |cluster,keyspaces|
        @clusters[cluster] = Cluster.new(self, cluster,keyspaces)
      end
      unsorted = {}
      @cfs.each_pair do |name,cf|
        unsorted[name] = TopoSort::Vertex.new(cf)
      end
      @cfs.each_pair do |name,cf|
        extends = cf.extends
        newextends = []
        extends.each do |other|
          rname = getRelativeName(cf,other)
          if rname != nil
            newextends.push(rname)
            TopoSort::Edge.new(unsorted[rname],unsorted[name])
          else
            #puts "ERROR: Could not find Column Family: #{other}"
          end
        end
        cf.extend!(newextends)
      end
      sorted = TopoSort::sort(unsorted.values)
      sorted.each do |v|
        v.data().load()
      end
    end
    def clusters()
      @clusters
    end
    def getCfByFullName(fullName)
      @cfs[fullName]
    end
    def getRelativeName(cf,name)
      if @cfs.key?(name)
        return name
      end
      rname = getRelativeName(cf,name)
      if @cfs.key?(rname)
        return rname
      end
      return nil
    end
    def getRelativeName(cf,name)
      "#{cf.cluster.name}/#{cf.keyspace.name}/#{name}"
    end
    def register(cf)
      name = getRelativeName(cf,cf.name)
      @cfs[name] = cf
      #puts "~~~ Register Column Family: #{name}"
    end
  end
end
