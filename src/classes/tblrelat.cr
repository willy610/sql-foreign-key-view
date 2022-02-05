require "./intpoint"
require "./rect"
require "./coverrect"
require "./intpoint"

alias FKDefTupleDecl = Tuple(String, String, String, String, String)

class TblRelat
  getter name : String
  getter row_number : Int32
  getter column_number : Int32
  getter tblnumber : Int32
  property pks # : Array(String)
  property fks # : Array(String)
  property fkdefs : Array(FKDefTupleDecl)
  property attributes # : Array(String)
  property width_TKN
  property height_TKN
  getter gridcellxyreal_PX : IntPoint
  setter gridcellxyreal_PX : IntPoint
  property outconnections
  property theCoverRectObj
  property channel_inconnection
  property all_in_refs_points_XY : Array(NamedTuple(x: Int32, y: Int32))
  property end_in_ref_XY : NamedTuple(x: Float32, y: Float32)

  def initialize(tblnumber)
    initialize("", 0, 0, tblnumber)
  end

  def initialize(@name, @row_number, @column_number, @tblnumber)
    @pks = Array(String).new
    @fks = Array(String).new
    @fkdefs = Array(FKDefTupleDecl).new
    @attributes = Array(String).new
    @width_TKN = 0
    @height_TKN = 0
    @channel_inconnection = 0
    @gridcellxyreal_PX = IntPoint.new(0, 0)
    @outconnections = Array(Hash(String, String | Int32 | Float32)).new
    @theCoverRectObj = Rect.new(0.to_f32, 0.to_f32, 0.to_f32, 0.to_f32)
    @all_in_refs_points_XY = Array(NamedTuple(x: Int32, y: Int32)).new
    @end_in_ref_XY = {x: 0.to_f32, y: 0.to_f32}
  end

  def set_pks(pks)
    @pks = pks
  end

  def set_attributes(a)
    @attributes = a
    @width_TKN = 2 + 2 + (a.clone << @name).max_of { |attr| attr.size }
    @height_TKN = 2 + a.size
  end

  def get_dims
    {@width_TKN, @height_TKN}
  end

  def getouterrect_PX
    {atx: @gridcellxyreal_PX.x, aty: @gridcellxyreal_PX.y, width: @theCoverRectObj.width_PX, heigth: @theCoverRectObj.height_PX}
  end

  def add_one_xy_in_refX( an_xy : NamedTuple(x: Int32, y: Int32) )
    # point 3 in the connection
    @all_in_refs_points_XY << an_xy
  end

  def gen_final_in_arc
    # We have one or more fk refs in to this table (all_in_refs_points_XY)
    # We need to know x,y for end ( end_in_ref_XY )

    # Reduce all all_in_refs_points_XY. Pick left and rightmost
    # Connect them into one shared line
    # and also an arrow up to self
    if all_in_refs_points_XY.size == 0
      return ""
    end
    # puts all_in_refs_points_XY
    all_at_same_y = all_in_refs_points_XY.first[:y]
    all_xs = all_in_refs_points_XY.map { |oneint| oneint[:x].to_f32 } << @end_in_ref_XY[:x]
    smallest = all_xs.min 
    biggest = all_xs.max
    mid = (smallest+biggest)/2.0
    "<line class='LINEFKPATHEND' x1='#{smallest}' y1='#{all_at_same_y}' x2='#{biggest}' y2='#{all_at_same_y}' />\n" +
      "<line class='LINEFKPATH' x1='#{end_in_ref_XY[:x]}' y1='#{all_at_same_y}' x2='#{end_in_ref_XY[:x]}' y2='#{end_in_ref_XY[:y]}'  />\n" +
      "<text class='PATHNUMBER' x='#{end_in_ref_XY[:x] + 3}' y='#{end_in_ref_XY[:y] + 10}'>#{@tblnumber}</text>\n" 
      # "<text class='PATHNUMBER' x='#{mid + 2}' y='#{all_at_same_y - 4}'>#{@tblnumber}</text>\n" 
  end

  def append_a_connection(one_connection)
    @outconnections << one_connection
  end

  def assvgbox(layoutdims, command_line_args)
    rectwidhtpx = @width_TKN*layoutdims[:tknvidd_PX]
    rectheightpx = @height_TKN*layoutdims[:tknhojd_PX]
    txt_at_x_PX = 2 * layoutdims[:tknvidd_PX]
    txt_at_y_PX = layoutdims[:tknhojd_PX]
    indentx_PX = txt_at_x_PX

    # COVER RECT
    @theCoverRectObj = Rect.new(0.to_f32,
      0.to_f32,
      @width_TKN*layoutdims[:tknvidd_PX].to_f32,
      @height_TKN*layoutdims[:tknhojd_PX].to_f32)

    outrect = "<g transform='translate(#{@gridcellxyreal_PX.x} #{@gridcellxyreal_PX.y})'>\n" +
              "<rect class='BOXID' x='0' y='0' width='#{@theCoverRectObj.width_PX}' height='#{@theCoverRectObj.height_PX}' rx='0'  ry='0'></rect>\n" +
              "<svg width='#{@theCoverRectObj.width_PX}' height='#{2 * layoutdims[:tknhojd_PX]}'>\n" +
              "<text class='TEXTTBLNAME' x='50%' y='#{txt_at_y_PX - 2}'>#{@name}</text>\n" +
              "</svg>\n"

    # OUTMOST COVER RECT PK's
    # =======================

    txt_at_y_PX = txt_at_y_PX + layoutdims[:tknhojd_PX]

    thePKRectObj = CoverRect.new(txt_at_x_PX, txt_at_y_PX,
      layoutdims,
      @pks.size,
      -2.to_f32,  # topmargin
      2.to_f32,   # bottommargin
      indentx_PX, # totalmargin
      2.to_f32/3.to_f32,
      @theCoverRectObj.width_PX
    )
    rectpk = if @pks.size > 0
               thePKRectObj.assvgrect("RECTPK")
             else
               ""
             end
    # FK
    #   Sort the fk in two groups in order to cover that all primarys is in to one rect!
    #   1. Thoose where from (any or all) columns are primary key (fkdef_from_pks)
    #   2. Thoose where from columns are NOT primary key (fkdef_from_others)

    groupedbyconstraintname = myGroupBy(@fkdefs, [colname_to_index("fk_name")])
    fkdef_from_pks = Array(String).new
    fkdef_from_others = Array(String).new
    draw_pk_cover = true
    groupedbyconstraintname.keys.map { |key_an_fk_def|
      this_fk_def = groupedbyconstraintname[key_an_fk_def]
      the_from_cols = this_fk_def.map { |adef|
        afkdef_as_tuple = FKDef.new(adef)
        afkdef_as_tuple.from_column
      }
      rest = the_from_cols - @pks
      if rest.size == the_from_cols.size
        # none was pk
        fkdef_from_others << key_an_fk_def.first
      else
        if rest.size == 0
          # all was pk
          fkdef_from_pks << key_an_fk_def.first
        else
          # NOT all was pk
          fkdef_from_pks << key_an_fk_def.first
          STDERR.puts "Warning: Mix of primary and none primary from columns in  #{key_an_fk_def.first}"
          draw_pk_cover = false
        end
      end
    }
    #
    #   All PK's rows
    #
    outsingularpks = String.new
    # Some fks might be pk. They will show up later
    (@pks - @fks).sort.each { |attr|
      outsingularpks += "<text class='TEXT' x='#{txt_at_x_PX}' y='#{txt_at_y_PX}'>*#{attr}</text>\n"
      txt_at_y_PX = txt_at_y_PX + layoutdims[:tknhojd_PX]
    }
    #
    # All FK. Each def rect an its content
    #
    rectfk = String.new
    outfks = String.new

    (fkdef_from_pks + fkdef_from_others).each do |anfkdef|
      rows_in_this_fkdef = groupedbyconstraintname[[anfkdef]]
      theFKRectObj = CoverRect.new(txt_at_x_PX, txt_at_y_PX,
        layoutdims,
        rows_in_this_fkdef.size,
        -3.to_f32,  # topmargin
        0.to_f32,   # bottommargin
        indentx_PX, # totalmargin
        1.to_f32/3.to_f32,
        theCoverRectObj.width_PX
      )
      rectfk += theFKRectObj.assvgrect("RECTFK")
      # each row is the same in :to_table , so take first
      # to_table = rows_in_this_fkdef[0][3]
      to_table = FKDef.new(rows_in_this_fkdef.first).to_table
      # Collect info on connections to other tables
      connection_to_other_table = {"from_table"  => @name,
                                   "constrname"  => anfkdef,
                                   "totable"     => to_table,
                                   "fromyRow_PX" => txt_at_y_PX.to_f32 -
                                                    layoutdims[:tknhojd_PX].to_f32 + 3.to_f32 +
                                                    rows_in_this_fkdef.size.to_f32 * layoutdims[:tknhojd_PX].to_f32 / 2.to_f32,
                                   "amount" => rows_in_this_fkdef.size}
      append_a_connection(connection_to_other_table)

      rows_in_this_fkdef.each { |onefkdef|
        attr = FKDef.new(onefkdef)
        if @pks.includes?(attr.from_column)
          outfks += "<text class='TEXT' x='#{txt_at_x_PX}' y='#{txt_at_y_PX}'>*#{attr.from_column}</text>\n"
        else
          outfks += "<text class='TEXT' x='#{txt_at_x_PX}' y='#{txt_at_y_PX}'>&#160;#{attr.from_column}</text>\n"
        end
        txt_at_y_PX = txt_at_y_PX + layoutdims[:tknhojd_PX]
      }
    end
    outattr = String.new
    (@attributes - @pks - @fks).sort.each { |attr|
      outattr += "<text class='TEXT' x='#{txt_at_x_PX}' y='#{txt_at_y_PX}'>#{attr}</text>\n"
      txt_at_y_PX = txt_at_y_PX + layoutdims[:tknhojd_PX]
    }
    endgrp = "</g>\n"
    ett = outrect + rectpk + outsingularpks + rectfk + outfks + outattr + endgrp
    ett
  end
end
