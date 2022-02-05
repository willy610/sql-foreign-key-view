require "./classes/tblrelat"
require "./classes/layoutcolumn"
require "./classes/layoutrow"
require "./classes/intpoint"
require "./classes/fkdef"

# Distribute tables into a matrix. Each matrix cell holds a table - or is empty
#
# Levels
# * First row - or column in case of transposed - holds all entity table names sorted on name
# * Each level holds table names which refers tabel in upper levels only
#
# Steps
# 1. (f_lay4) Find levels, create table obj for each cell, assign pks, attr and fkdefs for each table obj
#    Also assign size of each cell due size of table object
# 2. (f_lay5) Build spacings between table object due lines for foreign values
# 3. (f_lay6) Calculate x and for each table
# 4. (f-lay8) Collect all connections due to foreign keys
#
def all_layout(pks, table_and_attr, levels_IN, fkdefinitions, fkdefinitions_groupedby_fromtable,
               layoutdims, theDatabaseName, path_or_database, command_line_args)
  #
  scale = command_line_args["scale"].to_f32
  # A collection all table objects (TblRelat)
  alltblobj = [] of TblRelat
  # a layout_COLUMNS cover all tables in the same column.
  layout_COLUMNS = Array(LayoutColumn).new
  # a layout_ROWS cover all tables in the same row
  layout_ROWS = Array(LayoutRow).new
  # Holds width,height for each cell depending on max attribute name length and number of attributes
  cell_sizes_TKN = Array(Array({Int32, Int32})).new
  # Holds x,y in real space where each table is located
  cell_positions_TKN = Array(Array(IntPoint)).new

  levels_OUT = Array(Array(String)).new

  f_lay4 = ->{
    nr_tables_in_each_row = levels_IN.map { |alevel| l = alevel.size }
    maxtables_in_any_row = nr_tables_in_each_row.max_of { |c| c }
    cell_sizes_TKN = Array.new(levels_IN.size) { |i| Array.new(maxtables_in_any_row) { |j| {0, 0} } }
    levels_OUT = Array.new(levels_IN.size) { |i| Array.new(maxtables_in_any_row) { |j| "" } }
    levels_IN.map_with_index { |tables_on_this_level, rownumber|
      tables_on_this_level.map_with_index { |tablename, columnnumber|
        levels_OUT[rownumber][columnnumber] = tablename # NO MORE ""
      }
    }
    if command_line_args[:transpose]
      levels_OUT = levels_OUT.transpose
      cell_sizes_TKN = cell_sizes_TKN.transpose
    end
    tbl_obj_number = 1
    pks_group_by_from_table = myGroupBy(pks, [colname_to_index("from_table")])
    attr_group_by_from_table = myGroupBy(table_and_attr, [colname_to_index("from_table")])
    # begin new *********************************
    levels_OUT.map_with_index { |tables_on_this_level, rownumber|
      tables_on_this_level.map_with_index { |tablename, columnnumber|
        levels_OUT[rownumber][columnnumber] = tablename # NO MORE ""
        table_obj = TblRelat.new(tablename, rownumber, columnnumber, tbl_obj_number)
        if tablename.size != 0
          the_pks = pks_group_by_from_table[[tablename]].map { |tbl_and_column| tbl, col = tbl_and_column; col }
          # puts the_pks
          table_obj.set_pks(the_pks)
          table_obj.set_attributes(attr_group_by_from_table[[tablename]].map { |tbl_and_attr| tbl_and_attr[1] })
          if fkdefinitions_groupedby_fromtable.has_key?([tablename])
            myfkout = fkdefinitions_groupedby_fromtable[[tablename]]
            fk_from_columns = myfkout.map { |afkdef|
              FKDef.new(afkdef).from_column
            }
            # Tell obj about out fks and fkdefs
            table_obj.fks = fk_from_columns
            table_obj.fkdefs = myfkout
          end
        else
          # NOTHING. Dummy table obj with name "" and zero dimensions
        end
        # Ask for size the TblRelat needs
        cell_sizes_TKN[rownumber][columnnumber] = table_obj.get_dims
        tbl_obj_number += 1
        alltblobj << table_obj
      }
    }
    {cell_sizes_TKN, alltblobj}
  }
  # =====================================================

  f_lay5 = ->{
    colwitdhs_TKN = cell_sizes_TKN.clone.transpose.map { |cols| cols.max_of { |c| c[0] } }
    rowheights_TKN = cell_sizes_TKN.map { |rows| rows.max_of { |r| r[1] } }

    layout_COLUMNS = (1..colwitdhs_TKN.size).map { |_| LayoutColumn.new(command_line_args[:transpose]) }
    layout_COLUMNS.each_with_index { |a_lay_col, colnumber| a_lay_col.colwitdh_TKN = colwitdhs_TKN[colnumber] }

    layout_ROWS = (1..rowheights_TKN.size).map { |_| LayoutRow.new }
    layout_ROWS.each_with_index { |a_lay_row, rownumber| a_lay_row.rowheight_TKN = rowheights_TKN[rownumber] }

    alltblobj.each { |a_tbl_obj|
      if fkdefinitions_groupedby_fromtable.has_key?([a_tbl_obj.name])
        # this table has ref out
        fkdef_from_this_table = fkdefinitions_groupedby_fromtable[[a_tbl_obj.name]]
        # How many fk's ?
        group_on_fk_from = myGroupBy(fkdef_from_this_table, [colname_to_index("fk_name")]) # fk_name
        # One column for each OUT fk
        layout_COLUMNS[a_tbl_obj.column_number].add_some_out_fk(group_on_fk_from.values.size)
        # and add one row for each to row
        if !command_line_args["share_inconnections"]
          group_on_fk_from.each { |key, value|
            the_table_obj = find_tlbrelat_by_name(
              alltblobj,
              FKDef.new(value.first).to_table)
            layout_ROWS[the_table_obj.row_number].add_some_in_fk(1)
          }
        end
      end
    }
    # In case we are transposing columns self must know info from right neighbour
    (0..(layout_COLUMNS.size - 2)).each { |i|
      layout_COLUMNS[i].right_neighbour_nr_out_fk_TKN = layout_COLUMNS[i + 1].nr_out_fk_TKN
    }
    if command_line_args["share_inconnections"]
      # Now find thoose table having inrefs from fkdefs
      tables_having_inref = fkdefinitions.map { |afkdef| FKDef.new(afkdef).to_table }.uniq
      tables_having_inref.each { |to_table|
        the_table_obj = find_tlbrelat_by_name(alltblobj, to_table)
        layout_ROWS[the_table_obj.row_number].add_some_in_fk(1)
        the_table_obj.channel_inconnection = layout_ROWS[the_table_obj.row_number].nr_in_fk_TKN
      }
    end
    {colwitdhs_TKN, rowheights_TKN}
  }
  # =====================================================
  f_lay6 = ->{
    starty = 0
    # Now calculate real positions (cell_positions_TKN) for each table
    cell_sizes_TKN.map_with_index { |tables_on_this_level, rownumber|
      startx = layout_COLUMNS[0].get_start_x_depending_on_transpose(layoutdims)
      table_pos_x_y = Array(IntPoint).new

      tables_on_this_level.map_with_index { |width_and_heigth, colnumber|
        table_pos_x_y = table_pos_x_y << IntPoint.new(startx, starty)
        ny_dx = layout_COLUMNS[colnumber].dx_due_to_width_and_fks_and_space_TKN(layoutdims)
        startx = startx + ny_dx
      }
      cell_positions_TKN << table_pos_x_y

      ny_dy = layout_ROWS[rownumber].dy_due_to_height_and_fks_and_space_TKN(layoutdims)
      starty = starty + ny_dy
    }
    # Also tell layout_COLUMNS and layout_ROWS on positions
    levels_OUT.map_with_index { |colsinrow, rowYtkn|
      colsinrow.map_with_index { |atablename, colXtkn|
        theObj = find_tlbrelat_by_name(alltblobj, atablename)
        # Tell obj on positions
        theObj.gridcellxyreal_PX = cell_positions_TKN[rowYtkn][colXtkn]
      }
    }
    # Tell layouts on positions
    cell_positions_TKN[0].map_with_index { |xy, column|
      layout_COLUMNS[column].start_x_TKN = xy.x
    }
    (cell_positions_TKN.transpose)[0].map_with_index { |xy, row|
      layout_ROWS[row].start_y_TKN = xy.y
      layout_ROWS[row].yposchannelrow_TKN = layout_ROWS[row].start_y_TKN +
                                            layout_ROWS[row].rowheight_TKN * layoutdims[:tknhojd_PX]
    }
    cell_positions_TKN
  }
  # =====================================================
  f_lay8 = ->{
    svgtext = String.new
    allfkconnections = Array(Hash(String, String | Int32 | Float32)).new
    alltblobj.map { |thetblobj|
      # Create the svg for the table
      onetableassvg = thetblobj.assvgbox(layoutdims, command_line_args)
      svgtext = svgtext + onetableassvg
      # The method assvgbox() has calculated all fk connections (outconnections)
      thetblobj.outconnections.each { |one_connection| allfkconnections << one_connection }
    }
    # Calculate the whole svg dimensions
    width_PX = layout_COLUMNS.last.start_x_TKN +
               layout_COLUMNS.last.dx_due_to_width_and_fks_and_space_TKN(layoutdims)
    height_PX = layout_ROWS.last.start_y_TKN +
                layout_ROWS.last.dy_due_to_height_and_fks_and_space_TKN(layoutdims)

    conn = gen_connections(
      alltblobj,
      allfkconnections, layoutdims,
      layout_COLUMNS, layout_ROWS, command_line_args
    )
    totalsvg = get_cover_svg(width_PX, height_PX, theDatabaseName, svgtext.to_s, conn, scale)
    totalsvg
  }
  # =====================================================
  # all_layout STARTS HERE

  cell_sizes_TKN, alltblobj = f_lay4.call
  colwitdhs_TKN, rowheights_TKN = f_lay5.call
  cell_positions_TKN = f_lay6.call
  totalsvg = f_lay8.call
end

# =====================================================
def get_cover_svg(width_PX, height_PX, databasename, tables_as_as_svg, connections_as_svg, scale)
  # We have margins
  # The titel box has height
  # The box with all tables is of size width_PX, height_PX
  # And scale content of box
  margins = 20
  titelbox_height = 20
  titel_box_text_xy = {x: margins, y: margins}
  alltables_box = {x: margins, y: titel_box_text_xy[:y] + titelbox_height}

  width_Pix = margins + scale * width_PX + margins
  height_Pix = margins + alltables_box[:y] + scale * height_PX + margins

  # https://stackoverflow.com/questions/5546346/how-to-place-and-center-text-in-an-svg-rectangle

  "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\"
\"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">
<svg version='1.1' xmlns='http://www.w3.org/2000/svg'
xmlns:xlink='http://www.w3.org/1999/xlink'
id='canvas' width='#{width_Pix}' height='#{height_Pix}' preserveAspectRatio='xMidYMid' viewBox='0 0 #{width_Pix} #{height_Pix}'>
<defs><style type='text/css'>
.TEXTDB {font-size:12px;font-weight: bold;font-family: Menlo;stroke:none;fill:black;}
.TEXTTBLNAME {font-size:12px;font-weight: bold;font-family: Menlo;stroke:none;fill:black;text-anchor:middle}
.TEXT {font-size:12px;font-weight: normal;font-family: Menlo;stroke:none;fill:black;}
.PATHNUMBER {font-size:9px;font-weight: normal;font-family: Menlo;stroke:none;fill:black;}
.BOXID {fill:#F9F5D0;stroke:black;stroke-width:1;}
.RECTPK {stroke:blue;fill:none;stroke-width:0.5;}
.RECTFK {stroke:red;fill:none;stroke-width:0.5;}
.FKPATH {fill:none;stroke:green;stroke-width:0.8;}
.FKPATHEND {fill:none;stroke:green;stroke-width:2;}
.LINEFKPATH {stroke:blue;stroke-width:0.8;}
.LINEFKPATHEND {stroke:blue;stroke-width:2;}
.TITEL {font-size:130%;font-weight: normal;font-family: Lucida Console;stroke:none;fill:black;}
</style></defs>
<g transform='translate(#{titel_box_text_xy[:x]} #{titel_box_text_xy[:y]})'>
<text class='TEXTDB' x='0' y='0'>Database: #{databasename}</text>
</g>
<g transform='translate(#{alltables_box[:x]} #{alltables_box[:y]}) scale(#{scale})'>
#{tables_as_as_svg}
#{connections_as_svg}
</g>
</svg>"
end
