defmodule Benchmark do
  @moduledoc """
  Simple benchmarking utility, suitable for comparing multi-threaded performance.
  """
  require Logger

  @doc """
  Benchmark a single function.

  ## Options
  - `:tasks` number of concurrent tasks
  - `:count` total number of operations to run (ops per task is div(count, tasks))
  - `:bench_for` seconds to bench, estimates rate first
  """
  @spec bench((-> any()), keyword()) :: binary()
  def bench(fun, opts) do
    opts = Map.new(opts)
    tasks = opts[:tasks] || System.schedulers_online()

    case opts do
      %{bench_for: _, count: _} -> raise(RuntimeError, "use bench_for OR count")
      %{count: count} -> runtime(fun, tasks, count) |> to_rate(count) |> format_int()
      _ -> timed_bench(fun, tasks, opts[:bench_for] || 5) |> format_int()
    end
  end

  def bench(_opts = [fun | opts]), do: bench(fun, opts)
  def bench(fun), do: bench(fun, [])

  @doc """
  Benchmark and compare multiple things. Expects an enum of pairs of a name and a list of arguments for `bench/1`.
  """
  @spec bench_many(map() | keyword()) :: binary()
  def bench_many(pairs) do
    pairs
    |> Enum.map(fn {name, bench_args} ->
      name = to_string(name)
      IO.write("Running #{name}... ")

      {name, apply(__MODULE__, :bench, [bench_args])}
      |> tap(fn {_k, v} -> IO.puts("final #{v} ops/s, done.") end)
    end)
    |> tap(fn _ -> IO.puts("") end)
    |> format_results()
  end

  defp runtime(fun, 1, count) do
    start = System.monotonic_time(:nanosecond)
    repeat(fun, count)
    stop = System.monotonic_time(:nanosecond)
    stop - start
  end

  defp runtime(fun, tasks, count) do
    per_task = div(count, tasks)

    1..tasks
    |> Enum.map(fn _ -> Task.async(fn -> runtime(fun, 1, per_task) end) end)
    |> Task.await_many(:infinity)
    # max seems better then average; it's not done until it's all done
    |> Enum.max()
  end

  defp timed_bench(fun, tasks, target_duration) do
    estimated_rate = estimate_rate(fun, tasks)
    target_count = target_duration * estimated_rate
    runtime(fun, tasks, target_count) |> to_rate(target_count)
  end

  defp to_rate(duration, count), do: floor(count / duration * 1_000_000_000)

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

  defp format_int(int) do
    int
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.intersperse(~c"_")
    |> List.flatten()
    |> Enum.reverse()
    |> List.to_string()
  end

  defp repeat(fun, count)
  defp repeat(_, 0), do: :done

  defp repeat(fun, count) do
    fun.()
    repeat(fun, count - 1)
  end

  defp estimate_rate(fun, tasks, count \\ 1) do
    total_count = max(tasks, count)
    duration = runtime(fun, tasks, total_count)

    if duration > 100_000_000 do
      to_rate(duration, total_count) |> tap(&IO.write("estimate #{format_int(&1)} ops/s... "))
    else
      estimate_rate(fun, tasks, count * 10)
    end
  end
end
