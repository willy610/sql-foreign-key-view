require "option_parser"

def get_args
  the_engine_and_url = String.new
  the_database = String.new
  exclude_list = Array(String).new
  the_svg_file_name = String.new
  import_meta_files = Array(String).new
  scale = 1.0
  conncted_only = false
  attribute_hide = false
  transpose = false
  share_inconnections = false
  # final_args = Hash(String, String | Array(String) | Bool | Float32).new

  OptionParser.parse do |parser|
    parser.on "-v", "--version", "Show version" do
      puts "version 0.9"
      exit
    end
    parser.on "-h", "--help", "Show help" do
      puts parser
      exit
    end
    parser.on("-q", "--sqlengine SQLENGINE", "String to database open (DB.open())\nEx: mysql://user:password@localhost/information_schema") do |name|
      the_engine_and_url = name
    end
    parser.on("-d", "--database DATABASENAME", "Name of database to display. \nEx: sales") do |name|
      the_database = name
    end
    parser.on("-o", "--outsvgfile FILENAME", "Name of svg file displaying result\nEx: /svgs/sales.svg") do |name|
      the_svg_file_name = name
    end
    parser.on("-x", "--exclude LISTOFTABLE", "Exclude this list of tables\nEx: \"options,users,log,cakes\"") do |list|
      exclude_list = list.split(',')
    end
    parser.on("-c", "--connected_only", "Exclude all isolated tables") do
      conncted_only = true
    end
    parser.on("-a", "--attribute_hide", "Exclude all attributes. Focus on structure") do
      attribute_hide = true
    end
    parser.on("-z", "--zoom scale", "Scale with factor\nEx: -z 0.8 will scale down to 80%") do |value|
      scale = value.to_f32
    end
    parser.on("-i", "--import METAFILES", "Import from offline db\nEx: -i \"f1,f2,f3\"") do |list|
      import_meta_files = list.split(',')
    end
    parser.on("-t", "--transpose", "Let entity tables line in first column. Default is in first row") do
      transpose = true
    end
    parser.on("-s", "--share_inconnections", "Let inrefs share the same connection at end. Default now") do
      share_inconnections = true
    end
    parser.invalid_option do |flag|
      STDERR.puts "ERROR: #{flag} is not a valid option."
      STDERR.puts parser
      exit(1)
    end
  end

  final_args = {
    the_engine_and_url:  the_engine_and_url,
    the_database:        the_database,
    the_svg_file_name:   the_svg_file_name,
    exclude_list:        exclude_list,
    conncted_only:       conncted_only,
    attribute_hide:      attribute_hide,
    scale:               scale,
    import_meta_files:   import_meta_files,
    transpose:           transpose,
    share_inconnections: share_inconnections,
  }
  if (the_engine_and_url.size != 0 && import_meta_files.size == 0) ||
     (the_engine_and_url.size == 0 && import_meta_files.size != 0)
    final_args
  else
    if the_engine_and_url.size == 0
      STDERR.puts "-q or --sqlengine SQLENGINE must be givven"
      exit(1)
    end
    if import_meta_files.size == 0
      STDERR.puts "-i or --import fileset must be given"
      exit(1)
    end
    # will not come here
    final_args
  end
end
