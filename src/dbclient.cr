require "mysql"
require "pg"
require "sqlite3"
require "uri"

# https://crystal-lang.org/reference/1.2/database/index.html
# --------------------------------------------------------
# https://github.com/will/crystal-pg
#
# https://crystal-lang.org/reference/1.2/getting_started/cli.html#all-my-cli-the-complete-application
#
# https://stackoverflow.com/questions/1152260/how-to-list-table-foreign-keys

# The following resultset are required for a certain database
# 1: table_name, column_name
# 2: table_name, primary_key_column
# 3: table_name, fk_name, from_column, to_table, to_column

module DBClient
  class DBExecutor
    property tables_and_columns
    property tables_and_pks
    property fkdefs

    def initialize(the_db_url : String, theDatabaseName : String)
      begin
        aDB = DB.open the_db_url
      rescue except
        puts except.cause
        puts "Failed to connect to database when using '#{the_db_url}'"
        exit(1)
      end
      vendor = aDB.uri.scheme
      @tables_and_columns = Array({String, String}).new
      @tables_and_pks = Array({String, String}).new
      @fkdefs = Array(FKDefTupleDecl).new
      #
      # We do all database calls in this initialize
      #
      case vendor
      when "sqlite3"
        #
        # ***********
        # sqlite3
        # ***********
        #
        sql_1 = <<-SQL
SELECT
  m.name as table_name,
  p.name as column_name,
  p.pk
FROM
  sqlite_master AS m
JOIN
  pragma_table_info(m.name) AS p
ORDER BY
  m.name,
  p.cid;
SQL
        #
        sql_2 = <<-SQL
SELECT
  m.name as table_name,
  p.name as column_name
FROM
  sqlite_master AS m
JOIN
  pragma_table_info(m.name) AS p
  where p.pk = 1;
SQL
        #
        sql_3 = "PRAGMA foreign_key_list(SPJ);"
        begin
          @tables_and_columns = aDB.query_all(sql_1, as: {String, String})
          @tables_and_pks = aDB.query_all(sql_2, as: {String, String})

          tables = @tables_and_columns.map { |tbl_and_col| tbl_and_col[0] }.uniq
          tables.map { |table|
            sql_3 = "PRAGMA foreign_key_list(#{table});"
            result = aDB.query_all(sql_3, as: {Int64, Int64, String, String, String, String, String, String})
            result.each do |arow|
              fk_id = "fk_" + arow[0].to_s
              from_col = arow[3].to_s
              to_table = arow[2].to_s
              to_column = arow[4].to_s
              @fkdefs << {table, fk_id, from_col, to_table, to_column}
            end
          }
        rescue except
          puts except.cause
          puts "Perhaps no foreign keys"
          exit(1)
        end
        aDB.close
        # ***********
      when "mysql"
        #
        # ***********
        # mysql
        # ***********
        #
        sql_1 = <<-SQL
SELECT table_name  AS table_name,
    column_name AS column_name
FROM   information_schema.columns
WHERE  table_schema = '#{theDatabaseName}'
AND    table_name IN
      (
          SELECT table_name
          FROM   information_schema.tables
          WHERE  table_type='BASE TABLE'
          AND table_schema = '#{theDatabaseName}' );
SQL
        #
        sql_2 = <<-SQL
SELECT TABLE_NAME  AS table_name,
        COLUMN_NAME AS column_name
FROM   information_schema.KEY_COLUMN_USAGE
WHERE  CONSTRAINT_SCHEMA = '#{theDatabaseName}'
        AND CONSTRAINT_NAME = 'PRIMARY';
SQL
        #
        sql_3 = <<-SQL
SELECT TABLE_NAME            AS table_name,
      CONSTRAINT_NAME        AS fk_name,
      COLUMN_NAME            AS from_column,
      REFERENCED_TABLE_NAME  AS to_table,
      REFERENCED_COLUMN_NAME AS to_column
FROM   information_schema.KEY_COLUMN_USAGE
WHERE  TABLE_SCHEMA = '#{theDatabaseName}'
      AND CONSTRAINT_NAME IN (SELECT CONSTRAINT_NAME
                FROM   information_schema.TABLE_CONSTRAINTS
                WHERE  TABLE_SCHEMA = '#{theDatabaseName}'
                        AND CONSTRAINT_TYPE = 'FOREIGN KEY');
SQL
        #
        @tables_and_columns = aDB.query_all(sql_1, as: {String, String})
        @tables_and_pks = aDB.query_all(sql_2, as: {String, String})
        @fkdefs = aDB.query_all(sql_3, as: {String, String, String, String, String})
        aDB.close
        # ***********
      when "postgres"
        #
        # ***********
        # "postgres"
        # ***********
        #
        sql_1 = <<-SQL
SELECT table_name  AS table_name,
  column_name AS column_name
FROM   information_schema.columns
  WHERE  table_schema = 'public'
AND    table_name IN
(
        SELECT table_name
        FROM   information_schema.tables
        WHERE  table_type='BASE TABLE'
        AND table_schema = 'public' );
SQL
        #
        sql_2 = <<-SQL
SELECT information_schema.CONSTRAINT_COLUMN_USAGE.TABLE_NAME,
       information_schema.CONSTRAINT_COLUMN_USAGE.COLUMN_NAME
FROM   information_schema.TABLE_CONSTRAINTS
       JOIN information_schema.CONSTRAINT_COLUMN_USAGE USING (
       CONSTRAINT_SCHEMA, CONSTRAINT_NAME)
WHERE  information_schema.TABLE_CONSTRAINTS.CONSTRAINT_TYPE = 'PRIMARY KEY'
       AND information_schema.TABLE_CONSTRAINTS.TABLE_SCHEMA = 'public';
SQL
        #
        sql_3 = <<-SQL
SELECT
    tc.table_name AS table_name,
    tc.constraint_name fk_name,
    kcu.column_name from_column,
    ccu.table_name AS to_table,
    ccu.column_name AS to_column
FROM
    information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage
        AS kcu ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage
        AS ccu ON ccu.constraint_name = tc.constraint_name
WHERE constraint_type = 'FOREIGN KEY';
SQL
        #
        @tables_and_columns = aDB.query_all(sql_1, as: {String, String})
        @tables_and_pks = aDB.query_all(sql_2, as: {String, String})
        @fkdefs = aDB.query_all(sql_3, as: {String, String, String, String, String})
        aDB.close
      end
    end

    def initialize(fromFileNames : Array(String))
      # Read from three files
      @tables_and_columns = Array({String, String}).new
      File.each_line(fromFileNames[0]) do |line|
        split = line.split(',')
        @tables_and_columns << {split[0], split[1]}
      end
      @tables_and_pks = Array({String, String}).new
      File.each_line(fromFileNames[1]) do |line|
        split = line.split(',')
        @tables_and_pks << {split[0], split[1]}
      end
      @fkdefs = Array(FKDefTupleDecl).new
      File.each_line(fromFileNames[2]) do |line|
        split = line.split(',')
        @fkdefs << {split[0], split[1], split[2], split[3], split[4]}
      end
    end

    def filter_exclude_tables(exclude_list)
      @tables_and_columns = @tables_and_columns.reject { |t| exclude_list.includes?(t[0]) }
      @tables_and_pks = @tables_and_pks.reject { |t| exclude_list.includes?(t[0]) }
      @fkdefs = @fkdefs.reject { |t| exclude_list.includes?(t[0]) }
    end

    def get_table_names
      @tables_and_columns.map { |t_c| t_c[0] }.uniq
    end

    def get_primary_keys
      @tables_and_pks
    end

    def get_table_attr
      @tables_and_columns
    end

    def get_tables_without_pk
      get_table_names - get_primary_keys.map { |tbl, col| tbl }.uniq
    end

    def conncted_only
      theconnected = (@fkdefs.map { |onfkdef| [onfkdef[0], onfkdef[3]] }).flatten.uniq
      thetablenames = get_table_names()
      filter_exclude_tables(thetablenames - theconnected)
    end

    def exclude_attributes(to_exclude)
      if to_exclude
        # pick all {table,attributes}
        in_use = (fkdefs.map { |onefkdef| [{onefkdef[0], onefkdef[2]}, {onefkdef[3], onefkdef[4]}] } + tables_and_pks).flatten.uniq
        # in_use.each { |t_a| p t_a }
        # skip attributes not in use as pk or in fkdef
        # pick only attributes which are pk of in fkdef
        # @tables_and_columns = @tables_and_columns.reject { |t_a| !in_use.includes?(t_a) }
        @tables_and_columns = @tables_and_columns.select { |t_a| in_use.includes?(t_a) }
        # puts @tables_and_columns
      end
    end
  end
end
