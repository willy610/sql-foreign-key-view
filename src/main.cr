require "./utils"
require "./classes/fkdef"
require "./layout"
require "./commandlineargs"
require "./dbclient"
require "uri"

# --------------------------------------------------------
module Main
  theTables = Array(String).new
  fkdefinitions_groupedby_fromtable = Hash(Array(String), Array(FKDefTupleDecl)).new
  entitytables = Array(String).new
  relationshiptables = Array(String).new
  levels = Array(Array(String)).new
  pks = Array(String)
  levelsRECT = Array(Array(String)).new # HOLDS NAME OF TABLE

  # =====================================================
  f_find_entity_and_relat_tables = ->{
    tableshavingfkout = fkdefinitions_groupedby_fromtable.keys.map { |k| k[0] }
    entitytables = theTables - tableshavingfkout
    fkdefinitions_groupedby_fromtable.keys.map { |fromtable|
      fkdef = fkdefinitions_groupedby_fromtable[fromtable]
      has_refsout = fkdef.select { |onefkdef|
      afkdef_as_named_tuple = FKDef.new(onefkdef)
      afkdef_as_named_tuple.from_table != afkdef_as_named_tuple.to_table
      }
      if has_refsout.size == 0
        # Has fk to self only. Treat the table as an entity table
        entitytables << fromtable[0]
      end
    }
    relationshiptables = theTables - entitytables # rest of tabels are relationship tables
    {entitytables, relationshiptables}
  }
  # =====================================================
  f_buildlevels = ->{
    levels = [entitytables.sort]
    sofarlevelled = entitytables
    remainingtables = relationshiptables
    maxet = remainingtables.size # for security
    while maxet > 0 && remainingtables.size > 0
      maxet -= 1
      levellednow = [] of String
      remainingtables.each do |fromtable|
        thefkdef = fkdefinitions_groupedby_fromtable[[fromtable]] # key is like ["tablenameA"]
        # Do we have all pk out refs to sofarlevelled
        ref_to_levelled = thefkdef.select { |onefkdef|
          afkdef_as_named_tuple = FKDef.new(onefkdef)
          sofarlevelled.includes?(afkdef_as_named_tuple.to_table)
        }
        ref_to_remaings = thefkdef.select { |samefkdef|
          afkdef_as_named_tuple = FKDef.new(samefkdef)
          afkdef_as_named_tuple.to_table != afkdef_as_named_tuple.from_table &&
            remainingtables.includes?(afkdef_as_named_tuple.to_table)
        }
        if ref_to_levelled.size != 0 && ref_to_remaings.size == 0
          levellednow << fromtable
        end
      end # remainingtables.each
      if levellednow.size == 0
        STDERR.puts "Tables seems to be isolated (1) '#{remainingtables.to_s}'"
        exit(1)
      end
      levels = levels + [levellednow.sort]
      sofarlevelled = sofarlevelled + levellednow
      remainingtables = remainingtables - levellednow
    end # while
    levels
  }
  # =====================================================
  # Main starts here

  theDatabaseName = String.new
  command_line_args = get_args()
  the_database = command_line_args["the_database"]
  the_engine_and_url = command_line_args["the_engine_and_url"]
  # Read meta info from database
  if the_engine_and_url.size != 0
    theDatabaseName = if the_database.size == 0
                        (URI.parse the_engine_and_url).path
                      else
                        the_database
                      end
    theNewDB = DBClient::DBExecutor.new(the_engine_and_url, theDatabaseName)
  else
    theNewDB = DBClient::DBExecutor.new(command_line_args["import_meta_files"])
  end
  # Reduce the tables etc depending on options
  # -c
  if command_line_args["conncted_only"]
    theNewDB.conncted_only
  end
  # -x
  theNewDB.filter_exclude_tables(command_line_args["exclude_list"])
  tables_without_pk = theNewDB.get_tables_without_pk
  tables_without_pk.each { |tb| puts "table without pk excluded: #{tb}" }
  theNewDB.filter_exclude_tables(tables_without_pk)
  # -a
  theNewDB.exclude_attributes(command_line_args["attribute_hide"])

  theTables = theNewDB.get_table_names

  if theTables.size == 0
    STDERR.puts "ERROR: '#{theDatabaseName}' is not a known database or has no tables."
    exit(1)
  end

  # find PK for each table
  pks = theNewDB.get_primary_keys
  pks = pks.select { |tbl, col| theTables.includes?(tbl) }
  if pks.size == 0
    STDERR.puts "No primary keys found in any table"
    exit(1)
  end
  # Group all foreign definitions on 'from_table'
  fkdefinitions_groupedby_fromtable = myGroupBy(theNewDB.fkdefs, [colname_to_index("from_table")])
  # Find entity tables (has no fk outref; perhaps to self)
  # The rest is considered relationship tables
  entitytables, relationshiptables = f_find_entity_and_relat_tables.call
  # Assign tables to the right hierarchy level
  levels = f_buildlevels.call

  table_and_attr = theNewDB.get_table_attr

  # Collect attributes for each table
  table_and_attr = table_and_attr.select { |tbl, col| theTables.includes?(tbl) }
  # Find a proper name of the examined database
  path_or_database = if theDatabaseName.size > 0
                       theDatabaseName
                     else
                       (URI.parse the_engine_and_url).path
                     end
  # Set up stuff to final layout
  layoutdims = {tknvidd_PX: 8, tknhojd_PX: 15,
                rectpaddingleftright_PX: 15,
                rectpaddingtopbottom_PX: 15,
                colspacingfk_PX: 12,
                rowspacingfk_PX: 15}
  # Do layout and produce an svg string
  laid_out = all_layout(pks, table_and_attr, levels,
    theNewDB.fkdefs,
    fkdefinitions_groupedby_fromtable,
    layoutdims, theDatabaseName, path_or_database, command_line_args)
  # Save the svg file
  if command_line_args["the_svg_file_name"].size != 0
    file = File.new(command_line_args["the_svg_file_name"], "w")
    file.puts laid_out
    file.close
  end
end
