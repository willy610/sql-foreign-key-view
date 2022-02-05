class LayoutColumn
    property nr_out_fk_TKN : Int32
    property colwitdh_TKN : Int32
    property start_x_TKN : Int32
    property transposed : Bool
    property right_neighbour_nr_out_fk_TKN : Int32

    def initialize (transposed)
      @nr_out_fk_TKN = 0
      @colwitdh_TKN = 0
      @start_x_TKN = 0
      @right_neighbour_nr_out_fk_TKN = 0
      @transposed = transposed
    end
    # where does the first outgoing ref lines end and start going up or down
    def get_xpos_channel_start(layoutdims)
      if @transposed
        @start_x_TKN
      else
        @start_x_TKN + @colwitdh_TKN * layoutdims[:tknvidd_PX]
      end
    end
    # where does the rect around the table start
    def get_start_x_depending_on_transpose(layoutdims)
      if @transposed
        # We have outgoing fk lines to the left
        @nr_out_fk_TKN * layoutdims[:colspacingfk_PX] + layoutdims[:rectpaddingleftright_PX]
      else
        0
      end
    end
    def dx_due_to_width_and_fks_and_space_TKN(layoutdims)
      dx = @colwitdh_TKN * layoutdims[:tknvidd_PX]
      dx += layoutdims[:rectpaddingleftright_PX]
      dx += (if @transposed @right_neighbour_nr_out_fk_TKN else @nr_out_fk_TKN end) * layoutdims[:colspacingfk_PX]
    end

    def add_some_out_fk(some)
      @nr_out_fk_TKN += some
    end
  end
