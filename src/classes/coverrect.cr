class CoverRect
    getter atx_PX : Float32
    getter aty_PX : Float32
    getter width_PX : Float32
    getter height_PX : Float32

    def initialize(atxtx, atxty, layoutdims, nrrows, topmargin, bottommargin, totalmargin,
                   percentmargin, outmostwidth)
      @atx_PX = atxtx - totalmargin*percentmargin
      @aty_PX = atxty - layoutdims[:tknhojd_PX] - topmargin
      @width_PX = outmostwidth - 2.0*(1.0 - percentmargin) * totalmargin
      @height_PX = nrrows * layoutdims[:tknhojd_PX] + bottommargin
    end

    def assvgrect(theclass)
      "<rect class='#{theclass}' x='#{@atx_PX}' y='#{@aty_PX}' width='#{@width_PX}' height='#{@height_PX}' rx='0'  ry='0'></rect>\n"
    end
  end
