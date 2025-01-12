# Benchmark

A simple little utility to run a benchmark in Elixir. Benchee is most commonly used but it has its issues, especially that it constantly and annoyingly runs out of memory when calculating its statistics if you have a sample size that is too large, and it's not very useful for comparing multi-threaded performance. For some things, it's really useful to assess the impact of a highly concurrent environment, because performance can scale badly or even regress. Benchee doesn't really show this in a useful way, in my opinion.

This lib is not published on hex.pm because it's for personal use and I don't want to assume any maintenance burdens. It's small, limited, and publicly available as-is.

## Usage

```elixir
def deps do
  [
    {:benchmark, github: "juulSme/benchmark_ex"}
  ]
end
```

```elixir
iex> Benchmark.bench(fn -> :ok end, tasks: 1)
estimate 28_512_280 ops/s... 25943822

iex> Benchmark.bench_many(test: [fn -> :ok end, tasks: 1], test2: [fn -> :crypto.strong_rand_bytes(16) end])
...> |> Benchmark.format_results()
...> |> IO.puts()
Running test... estimate 26_910_886 ops/s... final 24_300_317 ops/s, done.
Running test2... estimate 2_085_631 ops/s... final 2_003_786 ops/s, done.

test:  24_300_317 ops/s
test2:  2_003_786 ops/s

```
