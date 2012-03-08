$LOAD_PATH << './lib'
require "cassagraphy/model.rb"
require "cassagraphy/render.rb" 

command = ARGV[0]

if ( command == 'render' )
  infile = ARGV[1]
  outfile = ARGV[2]
  puts "Render (#{outfile}) from #{infile}"
  model = Model::CassandraModel.new(infile)
  render = Render::HtmlTemplateRender.new(outfile)
  render.render(model)
elsif ( command == 'generate' )
  server = ARGV[1]
  outfile = ARGV[2]
  puts "Generate YAML (#{outfile}) for server #{server}"
  Model::generate(server,outfile)
else
  puts "Invalid Command '#{command}'"
end


