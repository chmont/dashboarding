# CPU Metrics — Dashboard Reference

## Overview

The CPU section of the dashboard provides visibility into **utilization, workload distribution, and saturation** across virtual machines. It combines high-level indicators with detailed breakdowns to help identify not just *how much* CPU is being used, but *why*.

---

## Core CPU Metrics

### 1. % Processor Time (Total CPU)

**Description:**
Represents overall CPU utilization as a percentage across all cores.

**What it tells you:**

* General system load
* Whether CPU is idle, moderate, or saturated

**Typical thresholds:**

* 0–70% → Normal
* 70–85% → Elevated
* 85%+ → High / potential concern

---

### 2. % User Time (Application CPU)

**Description:**
CPU time spent executing application-level processes.

**What it tells you:**

* Workload driven by applications
* High values indicate application demand

**Use case:**

* Identifying app-heavy workloads
* Correlating spikes with deployments or jobs

---

### 3. % Privileged Time (System CPU)

**Description:**
CPU time spent in kernel mode (operating system tasks).

**What it tells you:**

* OS-level activity (I/O, drivers, system services)
* High values may indicate:

  * Disk I/O pressure
  * Network activity
  * Driver/system overhead

---

### CPU Breakdown Relationship

In most cases:

```
% Processor Time ≈ % User Time + % Privileged Time
```

This allows you to understand whether CPU usage is driven by:

* applications (user time)
* system/kernel work (privileged time)

---

## CPU Saturation Metric

### 4. System Processor Queue Length

**Description:**
Number of threads waiting for CPU time.

**What it tells you:**

* Whether CPU is a bottleneck
* Indicates contention, not just usage

**Interpretation:**

* 0–2 → Healthy
* 2–5 → Moderate pressure
* 5+ → CPU contention (possible bottleneck)

**Important:**
Queue length is often more reliable than CPU % for detecting real performance issues.

---

## Key Insights & Patterns

### High CPU + Low Queue

* System is busy but handling load
* No immediate bottleneck

### High CPU + High Queue

* CPU is saturated
* Processes are waiting → performance impact

### High User Time

* Application-driven load
* Likely workload or scaling issue

### High Privileged Time

* System-driven load
* Possible causes:

  * disk I/O
  * network processing
  * inefficient drivers

### Low CPU + High Queue

* Potential scheduling or contention issue
* Worth investigating further

---

## How These Metrics Work Together

| Metric            | Purpose                     |
| ----------------- | --------------------------- |
| % Processor Time  | Overall utilization         |
| % User Time       | Application workload        |
| % Privileged Time | System/kernel workload      |
| Queue Length      | CPU contention / saturation |

Together, they answer:

> Is CPU high, what is causing it, and is it a bottleneck?

---

## Data Source

All CPU metrics are sourced from the **Perf table** in Azure Log Analytics.

**Relevant fields:**

* `ObjectName`: `"Processor Information"`
* `CounterName`: metric identifier
* `CounterValue`: numeric value of the metric
* `InstanceName`: `_Total` for all cores
* `TimeGenerated`: timestamp

---

## Summary

The CPU dashboard is designed to provide:

* **Utilization visibility** → how much CPU is used
* **Workload insight** → what is using the CPU
* **Saturation detection** → whether CPU is a bottleneck

This combination enables faster troubleshooting and more accurate capacity planning.

---
