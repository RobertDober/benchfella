defmodule Benchfella.Snapshot do
  alias __MODULE__
  defstruct options: %{}, tests: %{}

  def parse(str) do
    [header | rest] = String.split(str, "\n")

    options =
      header
      |> String.split(";")
      |> Enum.map(&String.split(&1, ":"))
      |> Enum.map(fn [name, val] -> {name, parse_opt(name, val)} end)

    tests =
      rest
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.split(&1, ":"))
      |> Enum.map(fn [name, count, elapsed] ->
        {name, {String.to_integer(count), String.to_integer(elapsed)}}
      end)

    %Snapshot{options: Enum.into(options, %{}), tests: Enum.into(tests, %{})}
  end

  defp parse_opt("duration", val), do: String.to_float(val)
  defp parse_opt("mem stats", val), do: parse_bool(val)
  defp parse_opt("sys mem stats", val), do: parse_bool(val)

  defp parse_bool("false"), do: false
  defp parse_bool("true"), do: true

  def compare(%Snapshot{tests: tests1}, %Snapshot{tests: tests2}, format \\ :ratio) do
    name_set1 = Map.keys(tests1) |> Enum.into(HashSet.new)
    name_set2 = Map.keys(tests2) |> Enum.into(HashSet.new)
    common_tests = Set.intersection(name_set1, name_set2)
    diffs = Enum.reduce(common_tests, %{}, fn name, diffs ->
      {count, elapsed} = tests1[name]
      result1 = elapsed / count

      {count, elapsed} = tests2[name]
      result2 = elapsed / count

      Map.put(diffs, name, diff(result1, result2, format))
    end)
    {diffs, symm_diff(name_set1, name_set2) |> Enum.into([])}
  end

  def format_percent(0.0) do
    "--"
  end

  def format_percent(num) do
    str = if num > 0 do <<?+>> else <<>> end
    str <> Float.to_string(num, decimals: 2) <> "%"
  end

  defp diff(r1, r2, :ratio), do: Float.round(r2 / r1, 2)
  defp diff(r1, r2, :percent), do: ratio_to_percent(r2 / r1)

  def ratio_to_percent(ratio), do: Float.round(log2(ratio) * 100, 2)

  defp log2(x), do: :math.log(x) / :math.log(2)

  defp symm_diff(set1, set2) do
    Set.union(Set.difference(set1, set2), Set.difference(set2, set1))
  end
end