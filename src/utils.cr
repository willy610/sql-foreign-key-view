# myGroupBy(rows, grpon)

# Will collect Arrara(rows) into groups depending on Array(grpon)
#
# rows are ``[[1,2,3,4],[5,6,7,8],[1,2,4,3]]``
#
# and grpon is ``[0,1]``
#
# then myGroupBy(rows, grpon) will be
#
# result is ``Hash{[1,2]=>[[1,2,3,4],[1,2,4,3],[5,6]=>[[5,6,7,8]]}``
def myGroupBy(rows, grpon)
  rows.group_by { |arow| grpon.map { |an_index_in_row| arow[an_index_in_row] } }
end

def colname_to_index(colname)
  # --------------------------------------------------------
  index = case colname
          when "from_table"
            0
          when "fk_name"
            1
          when "from_column"
            2
          when "to_table"
            3
          when "to_column"
            4
          else STDERR.puts
          "function 'colname_to_index' can't translate colname=#{colname}"; exit(1)
          end
end

# --------------------------------------------------------

def arrow(p1, p2, arrownumber)
  middle = {x: (p1[:x] + p2[:x])/2, y: (p1[:y] + p2[:y])/2}
  rotate, dx, dy = if p1[:x] < p2[:x]
                     [0, 5, -4] # Right
                   elsif p1[:x] > p2[:x]
                     [180, -10, -4] # Left
                   elsif p1[:y] < p2[:y]
                     [90, 5, 10] # Down
                   elsif p1[:y] > p2[:y]
                     [-90, 5, 0] # Up
                   else
                     [0, 0, 0]
                   end
  retarrow = "<g transform='translate(#{middle[:x]} #{middle[:y]}) rotate(#{rotate}) scale(2)'> " +
             " <path d='M 5 0 L 0 -2 L 2 0 L 0 2 L 5 0' fill='black' /></g>\n"
  retnumber = "<text class='PATHNUMBER' x='#{middle[:x] + dx}' y='#{middle[:y] + dy}'>#{arrownumber}</text>\n"
  retarrow + retnumber
end

# --------------------------------------------------------

def find_tlbrelat_by_name(alltblobj, thename)
  alltblobj.select { |obj| obj.name == thename }.first
end

# --------------------------------------------------------

def gen_connections(
  alltblobj,
  allfkconnections, layoutdims,
  layout_COLUMNS, layout_ROWS,
  command_line_args
)
  # We will gen
  # - line right out, or left out depending on -t, from fkdef (p1,p2)
  # - line up/down to bottom of dest table (p2,p3)
  # ## - line left/right to middle of dest table (p3,p4)
  # ## - Some arrows and digts along the line (p4,p5)
  #
  columnchannelsoffset = layout_COLUMNS.map { |acolumn|
    if !command_line_args[:transpose]
      1 # left to right
    else
      acolumn.nr_out_fk_TKN # right to left
    end
  }
  rowchannelsoffset = Array.new(layout_ROWS.size) { 1 }

  allconnections = String.new
  allfkconnections.each { |one_conn|
    fromobj = find_tlbrelat_by_name(alltblobj, one_conn["from_table"])
    outerrect_from_PX = fromobj.getouterrect_PX
    toobj = find_tlbrelat_by_name(alltblobj, one_conn["totable"])
    yrow_PX = one_conn["fromyRow_PX"].to_f32
    tocolXcell = fromobj.column_number
    torowYcell = toobj.row_number

    if !command_line_args[:transpose]
      p1 = {x: outerrect_from_PX[:atx] + outerrect_from_PX[:width] -
               4 * layoutdims[:tknvidd_PX] / 3,
            y: outerrect_from_PX[:aty] + yrow_PX}
      p2 = {x: layout_COLUMNS[tocolXcell].get_xpos_channel_start(layoutdims) +
               layoutdims[:colspacingfk_PX] * columnchannelsoffset[tocolXcell],
            y: p1[:y]}
      pa = {x: (p1[:x] + p2[:x]) / 2 + 2 * layoutdims[:tknvidd_PX] / 3,
            y: (p1[:y] + p2[:y]) / 2 - 2}
    else
      p1 = {x: outerrect_from_PX[:atx] + 4 * layoutdims[:tknvidd_PX]/3,
            y: outerrect_from_PX[:aty] + yrow_PX}
      p2 = {x: layout_COLUMNS[tocolXcell].get_xpos_channel_start(layoutdims) -
               columnchannelsoffset[tocolXcell] * layoutdims[:colspacingfk_PX],
            y: p1[:y]}
      pa = {x: p2[:x] + 1*layoutdims[:tknvidd_PX]/3,
            y: (p1[:y] + p2[:y])/2 - 2}
    end
    if !command_line_args[:transpose]
      columnchannelsoffset[tocolXcell] += 1
    else
      columnchannelsoffset[tocolXcell] -= 1
    end

    if command_line_args["share_inconnections"]
      p3 = {x: p2[:x],
            y: layout_ROWS[torowYcell].yposchannelrow_TKN +
               layoutdims[:rowspacingfk_PX] * toobj.channel_inconnection}
    else
      p3 = {x: p2[:x],
            y: layout_ROWS[torowYcell].yposchannelrow_TKN + layoutdims[:rowspacingfk_PX] * rowchannelsoffset[torowYcell]}
      # consume one rowchannelsoffset
      rowchannelsoffset[torowYcell] = rowchannelsoffset[torowYcell] + 1
    end
    toobj.add_one_xy_in_refX(p3)

    # Just in the middle bottom of torect
    outerrect_to_PX = toobj.getouterrect_PX

    toobj.end_in_ref_XY = {x: outerrect_to_PX[:atx] + outerrect_to_PX[:width]/2,
                           y: outerrect_to_PX[:aty] + outerrect_to_PX[:heigth]}
    # DONE
    p4 = {x: outerrect_to_PX[:atx] + outerrect_to_PX[:width]/2,
          y: p3[:y]}

    p5 = {x: p4[:x],
          y: outerrect_to_PX[:aty] + outerrect_to_PX[:heigth]}

    if command_line_args["share_inconnections"]
      oneconn = "<path class='FKPATH' d='M #{p1[:x]} #{p1[:y]} L #{p2[:x]} #{p2[:y]} L #{p3[:x]} #{p3[:y]} ' />\n"
      retnummerstart = "<text class='PATHNUMBER' x='#{pa[:x]}' y='#{pa[:y]}'>#{toobj.tblnumber}</text>\n"
      pil1 = arrow(p2, p3, toobj.tblnumber)
      allconnections = allconnections + oneconn + retnummerstart + pil1
    else
      oneconn = "<path class='FKPATH' d='M #{p1[:x]} #{p1[:y]} L #{p2[:x]} #{p2[:y]} L #{p3[:x]} #{p3[:y]} \n " +
                " L #{p4[:x]} #{p4[:y]} L #{p5[:x]} #{p5[:y]}' />\n"
      retnummerstart = "<text class='PATHNUMBER' x='#{pa[:x]}' y='#{pa[:y]}'>#{toobj.tblnumber}</text>\n"
      # x = p5[:x] + 2
      # y = p5[:y] + 9
      p6 = {x: p5[:x] + 2, y: p5[:y] + 11}
      retnummerslut = "<text class='PATHNUMBER' x='#{p6[:x]}' y='#{p6[:y]}'>#{toobj.tblnumber}</text>\n"
      pil1 = arrow(p2, p3, toobj.tblnumber)
      pil2 = arrow(p3, p4, toobj.tblnumber)
      allconnections = allconnections + oneconn + retnummerstart + retnummerslut + pil1 + pil2
    end
  }
  allconnections + if command_line_args["share_inconnections"]
    alltblobj.map { |an_tbl_obj| an_tbl_obj.gen_final_in_arc }.join("\n")
  else
    ""
  end
end
