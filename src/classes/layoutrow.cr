class LayoutRow
  property nr_in_fk_TKN : Int32
  property rowheight_TKN : Int32
  property start_y_TKN : Int32
  property yposchannelrow_TKN : Int32

  def initialize
    @nr_in_fk_TKN = 0
    @rowheight_TKN = 0
    @start_y_TKN = 0
    @yposchannelrow_TKN = 0
  end

  def dy_due_to_height_and_fks_and_space_TKN(layoutdims)
    rowheight_TKN * layoutdims[:tknhojd_PX] +
      nr_in_fk_TKN * layoutdims[:rowspacingfk_PX] +
      layoutdims[:rectpaddingtopbottom_PX]
  end

  def add_some_in_fk(some)
    @nr_in_fk_TKN += some
  end
end
