record FKDef, from_table : String, fk_name : String,
  from_column : String, to_table : String, to_column : String

struct FKDef
  def initialize(ar : FKDefTupleDecl)
    @from_table = ar[0]
    @fk_name = ar[1]
    @from_column = ar[2]
    @to_table = ar[3]
    @to_column = ar[4]
  end
  def initialize(ar : Array(String))
    @from_table = ar[0]
    @fk_name = ar[1]
    @from_column = ar[2]
    @to_table = ar[3]
    @to_column = ar[4]
  end
end

