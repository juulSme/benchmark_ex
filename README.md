# Benchmark

A simple little utility to run a benchmark in Elixir. Benchee is most commonly used but it has its issues, especially that it constantly and annoyingly runs out of memory when calculating its statistics if you have a sample size that is too large, and it's not very useful for comparing multi-threaded performance. For some things, it's really useful to assess the impact of a highly concurrent environment, because performance can scale badly or even regress. Benchee doesn't really show this in a useful way, in my opinion.

This lib is not published on hex.pm because it's for personal use and I don't want to assume any maintenance burdens. It's small, limited, and publicly available as-is.

```elixir
def deps do
  [
    {:benchmark, github: "juulSme/benchmark_ex"}
  ]
end
```
