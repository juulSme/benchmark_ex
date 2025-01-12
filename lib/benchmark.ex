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
  @spec bench((-> any()), keyword()) :: integer()
  def bench(fun, opts) do
    opts = Map.new(opts)
    tasks = opts[:tasks] || System.schedulers_online()

    case opts do
      %{bench_for: _, count: _} -> raise(RuntimeError, "use bench_for OR count")
      %{count: count} -> runtime(fun, tasks, count) |> to_rate(count)
      _ -> timed_bench(fun, tasks, opts[:bench_for] || 5)
    end
  end

  def bench(_opts = [fun | opts]), do: bench(fun, opts)
  def bench(fun), do: bench(fun, [])

  @doc """
  Benchmark and compare multiple things. Expects an enum of pairs of a name and a list of arguments for `bench/1`.
  """
  @spec bench_many(map() | keyword()) :: [{String.t() | atom(), integer()}]
  def bench_many(pairs) do
    pairs
    |> Enum.map(fn {name, bench_args} ->
      IO.write("Running #{name}... ")

      {name, apply(__MODULE__, :bench, [bench_args])}
      |> tap(fn {_k, v} -> IO.puts("final #{format_int(v)} ops/s, done.") end)
    end)
    |> tap(fn _ -> IO.puts("") end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  def format_results(results) do
    results = Enum.map(results, fn {name, result} -> {to_string(name), format_int(result)} end)

    {name_length, result_length} =
      Enum.reduce(results, {0, 0}, fn {name, result}, {name_length, result_length} ->
        {max(name_length, String.length(name)), max(result_length, String.length(result))}
      end)

    results
    |> Stream.map(fn {name, result} ->
      name = String.pad_trailing(name <> ":", name_length + 1)
      result = String.pad_leading(result, result_length)
      "#{name} #{result} ops/s"
    end)
    |> Enum.join("\n")
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
