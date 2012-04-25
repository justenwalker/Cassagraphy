require "cassagraphy/model.rb"

module Render
  class Template
    def initialize(filename)
      @filename = filename
    end
    def render(params)
      content = File.read(@filename)
      params.each_pair do |k,v|
        content = content.gsub(/\$\{#{k}\}/,params[k])
      end
      return content
    end
  end
  class HtmlTemplateRender
    def initialize(filename)
      @filename = filename
      @templates = {}
      @templates['model']        = Template.new("templates/model.htm") 
      @templates['cluster']      = Template.new("templates/cluster.htm") 
      @templates['keyspace']     = Template.new("templates/keyspace.htm") 
      @templates['columnfamily'] = Template.new("templates/columnfamily.htm") 
      @templates['column']       = Template.new("templates/column.htm")
      @templates['supercolumn']  = Template.new("templates/supercolumn.htm")
      @templates['repeat']       = Template.new("templates/repeat.htm")
    end
    def renderRepeat(content) 
      params = {}
      params['content'] = content
      @templates['repeat'].render(params)
    end
    def renderColumn(col)
      r = ""
      col.columns.each do |c|
          params = {}
          params['name'] = c.name
          params['value'] = c.value
	  if c.hasTtl?
	    params['ttl'] = c.ttl
	    params['ttlClass'] = 'ttl'
	  else
	    params['ttlClass'] = 'no-ttl'
	  end
          if c.optional?
            params['optional'] = "optional"
          else
            params['optional'] = ""
          end
          if( c.repeat? )
            r += renderRepeat(@templates['column'].render(params))
          else
            r += @templates['column'].render(params)
          end
      end
      return r
    end
    def renderSuperColumn(scol)
      params = {}
      params['key'] = scol.key
      if( scol.optional? )
      	params['optional'] = 'optional'
      else
        params['optional'] = '' 
      end
      params['columns'] = renderColumn(scol.columns)
      return @templates['supercolumn'].render(params)
    end
    def renderColumnFamily(cf)
      params = {}
      params['name'] = cf.name
      params['key']  = cf.key
      params['columns'] = ""
      params['class'] = "columnfamily"
      params['prefix'] = ""
      col = cf.columns
      if cf.super?
        params['prefix'] = 'Super'
        params['class'] = 'supercolumnfamily'
        params['columns'] = renderSuperColumn(col)
        if ( col.repeat? )
          params['columns'] = renderRepeat(params['columns'])
        end
      else
        params['columns'] = renderColumn(col)
      end
      return @templates['columnfamily'].render(params)
    end
    def renderKeyspace(keyspace)
      params = {}
      params['name'] = keyspace.name
      params['schema'] = ""
      cfs = keyspace.columnfamilies
      cfs.each_pair do |name,cf|
        params['schema'] += renderColumnFamily(cf)
      end
      return @templates['keyspace'].render(params)
    end
    def renderCluster(cluster)
      params = {}
      params['name'] = cluster.name
      params['schema'] = ""
      cluster.keyspaces().each_pair do |name,keyspace|
        params['schema'] += renderKeyspace(keyspace)
      end
      return @templates['cluster'].render(params)
    end
    def render(model)
      params = {}
      params['title'] = "Cassandra Data Model"
      result = ""
      model.clusters.each_pair do |name,cluster|
        result += renderCluster(cluster)
      end
      params['body'] = result
      params['style'] = File.read('templates/style.css')
      params['script'] = File.read('templates/script.js')
      File.open(@filename,'w') { |f| f.write(@templates['model'].render(params)) }
    end
  end
end
