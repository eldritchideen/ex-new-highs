defmodule Stocks do
  @moduledoc """
  Fetch and process the list of shares making new yearly highs.

  """


  # Test only method to help generate data for REPL based testing.
  # TODO: Remove from final source.
  def get_highs do
    %{}
    |> Map.put({2015, 6, 17} , ["FLN", "MIG", "FMG", "SHL"])
    |> Map.put({2015, 6, 18} , ["FMG", "CTX", "XYZ"])
  end

  defp month_to_num(month) do
    case month do
      "Jan" -> 1
      "Feb" -> 2
      "Mar" -> 3
      "Apr" -> 4
      "May" -> 5
      "Jun" -> 6
      "Jul" -> 7
      "Aug" -> 8
      "Sep" -> 9
      "Oct" -> 10
      "Nov" -> 11
      "Dec" -> 12
    end
  end

  defp date_to_str({year, mon, day}) do
    "#{year}-#{mon}-#{day}"
  end


  def get_html do
    resp = HTTPoison.get!("http://www.smh.com.au/business/markets/52-week-highs?page=-1",[], [])
    resp.body
  end

  @doc """
  Find the shares making new highs and return a list of their share codes.
  """
  def get_new_highs(html) do
    Floki.find(html, "#content  section  table  tbody  tr  th  a")
    |> Enum.map(fn({_,_,[code]}) -> code end)
  end

  @doc """
  Get the date for the shares.
  """
  def get_date(html) do
    [{"time", _, [date]}] = Floki.find(html,"#content section header p time")
    [_, mon, day, _, _, year] = String.split(date)
    {String.to_integer(year), month_to_num(mon), String.to_integer(day)}
  end

  @doc """
  Given a Map of share data, fetch new data from the web and update the Map.

  Contents of the Map are in the format:
    {date} => [share codes]
  """
  def update_new_highs(highs) do
    html = get_html()
    date = get_date(html)
    new_highs = get_new_highs(html)

    Map.put(highs, date, new_highs)
  end

  @doc """
  Encode the contents of the Map to a CSV format for file storage.
  """
  def highs_to_str(highs) do
    Enum.reduce(highs, "",
      fn ({date, new_highs}, acc) ->
        acc <> date_to_str(date) <> ","
            <> Enum.join(new_highs, ",") <> "\n" end)
  end

  @doc """
  Write the new high Map to file.
  """
  def write_highs(highs, file) do
    File.write!(file, highs_to_str(highs), [:write])
  end

  @doc """
  Given a line from the CSV file, decode it back into Elixir data.
  """
  defp decode_str(str) do
    [x|xs] = String.split(str, ",", trim: true)
    [year, mon, day] = Enum.map(String.split(x, "-"), &String.to_integer/1)
    {{year, mon, day}, xs}
  end

  @doc """
  Read in previous new high data and store it in a Map.
  """
  def read_highs(file) do
    case File.read(file) do
      {:ok, lines} ->
        lines
        |> String.split("\n", trim: true)
        |> Enum.reduce(%{},
            fn (x, acc) ->
              {k, v} = decode_str(x)
              Map.put(acc, k, v)
            end)
      {:error, _} -> %{}
    end
  end

  def consolidate_to_week(highs) do
    highs
    |> Stream.map(fn ({k,v}) -> {Chronos.beginning_of_week(k), v} end)
    |> Enum.reduce( %{},
         fn ({k,v}, acc) ->
           lst = case Map.fetch(acc, k) do
             {:ok, val} -> val
             :error -> []
           end
           Map.put(acc, k, lst ++ v)
         end)
    |> Stream.map(fn ({k,v}) -> {k, count_highs v} end)
    |> Enum.into(%{})
  end

  def count_highs(xs) do
    Enum.reduce(xs, %{},
      fn (x, acc) ->
        count = Map.get(acc, x, 0)
        Map.put(acc, x, count + 1)
      end)
    |> Enum.into([])
    |> Enum.sort(fn ({_, x}, {_, y}) -> x > y end)
  end

  def main() do
    highs = read_highs("asx-highs.csv")
    highs = update_new_highs(highs)
    write_highs(highs,"asx-highs.csv")
    highs
  end

  def loop() do
    main()
    :timer.sleep(60_000)
    loop()
  end

  def run() do
    spawn(fn ->
      loop()
    end)
  end

end
