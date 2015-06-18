defmodule StocksTest do
  use ExUnit.Case

  defp get_highs do
    HashDict.new
    |> Dict.put({2015, 6, 17} , ["FLN", "MIG", "TAN", "SHL"])
    |> Dict.put({2015, 6, 18} , ["FMG", "CTX", "XYZ"])
  end

  test "encode to csv" do
    assert Stocks.highs_to_str(get_highs()) == "2015-6-18,FMG,CTX,XYZ,\n2015-6-17,FLN,MIG,TAN,SHL,\n"
  end

  

end
