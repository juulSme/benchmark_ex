defmodule Benchmark do
  @moduledoc """
  Simple benchmarking utility, suitable for comparing multi-threaded performance.
  """

  @doc """
  Benchmark a single function.

  ## Options
  - `:processes` number of concurrent processes
  - `:count` total number of operations to run (ops per task is div(count, processes))
  """
  @spec bench((-> any()), keyword()) :: binary()
  def bench(fun, opts \\ []) do
    processes = opts[:processes] || System.schedulers_online()
    count = opts[:count] || 10_000_000
    fn _ -> fun.() end |> do_bench(processes, count)
  end

  defp do_bench(fun, 1, count) do
    start = System.monotonic_time(:nanosecond)
    1..count |> Stream.each(fun) |> Stream.run()
    stop = System.monotonic_time(:nanosecond)
    calc_rate(count, start, stop)
  end

  defp do_bench(fun, tasks, count) do
    per_task = div(count, tasks)
    start = System.monotonic_time(:nanosecond)

    1..tasks
    |> Enum.map(fn _ ->
      Task.async(fn ->
        1..per_task |> Stream.each(fun) |> Stream.run()
      end)
    end)
    |> Task.await_many(:infinity)

    stop = System.monotonic_time(:nanosecond)
    calc_rate(count, start, stop)
  end

  @doc """
  Benchmark and compare multiple things. Expects an enum of pairs of a name and a list of arguments for `bench/1`.
  """
  @spec bench_many(map() | keyword()) :: binary()
  def bench_many(pairs) do
    pairs
    |> Enum.map(fn {name, bench_args} ->
      IO.write("Running #{name}... ")
      {name, apply(__MODULE__, :bench, bench_args)} |> tap(fn _ -> IO.puts("done.") end)
    end)
    |> tap(fn _ -> IO.puts("") end)
    |> format_results()
  end

  defp format_results(results) do
    name_length = Enum.reduce(results, 0, fn {name, _}, acc -> max(acc, String.length(name)) end)
    res_length = Enum.reduce(results, 0, fn {_, res}, acc -> max(acc, String.length(res)) end)

    results
    |> Enum.map(fn {name, result} ->
      {String.pad_trailing(name <> ":", name_length + 1), String.pad_leading(result, res_length)}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.map(fn {name, result} -> "#{name} #{result} ops/s" end)
    |> Enum.join("\n")
  end

  defp calc_rate(count, start, stop) do
    duration = stop - start
    floor(count / duration * 1_000_000_000) |> format_int()
  end

  defp format_int(int) do
    int
    |> Integer.to_string()
    |> String.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.intersperse(~c"_")
    |> List.flatten()
    |> Enum.reverse()
    |> List.to_string()
  end
end
