# EMPRETEL Sentinel

**Monitor. Notify. Recover.**

A lightweight Linux monitoring, notification and self-recovery toolkit.
Detect failures, send alerts through pluggable providers, and execute
automated recovery actions using simple Bash plugins.

EMPRETEL Sentinel is designed for Linux administrators who need transparent
health checks, notifications and controlled recovery actions without
deploying a heavyweight monitoring stack.

---

## Core Principles

- Simple Bash components
- Human-readable service plugins
- Pluggable notification providers
- Configuration and secrets outside the repository
- Explicit and controlled recovery actions
- Useful exit codes for scripts, systemd and automation tools

---

## Requirements

- Linux
- Bash
- curl

Individual service plugins may declare additional dependencies.

---

## Architecture

```text
empretel-sentinel
        │
        ├── bin/
        │     ├── empretel-sentinel
        │     ├── empretel-notify
        │     └── empretel-recover
        │
        ├── providers/
        │     └── callmebot.sh
        │
        ├── services/
        │     └── <service>/
        │           ├── monitor.sh
        │           ├── recover.sh
        │           └── service.conf.example
        │
        └── lib/
              └── common.sh
```

The core contains **no service-specific logic**.

Every monitored service is implemented as an independent plugin.

---

## Commands

List installed services:

```bash
empretel-sentinel list
```

Run a health check:

```bash
empretel-sentinel check example
```

Recover a service:

```bash
empretel-recover example
```

Send a notification:

```bash
empretel-notify success "Sentinel is working."
```

---

## Monitor Exit Codes

| Code | Status |
|-----:|--------|
| 0 | OK |
| 1 | WARNING |
| 2 | CRITICAL |
| 3 | UNKNOWN |

---

## Recovery Exit Codes

| Code | Meaning |
|-----:|---------|
| 0 | Recovery succeeded |
| 1 | Recovery failed |
| 2 | Recovery not applicable |
| 3 | Unknown recovery status |

---

## Installation

Clone the repository:

```bash
git clone https://github.com/fafamonge/empretel-sentinel.git
cd empretel-sentinel
```

Install:

```bash
sudo ./install.sh
```

Edit the local configuration:

```bash
sudo vi /etc/empretel-sentinel/sentinel.conf
```

The real configuration is intentionally kept outside the repository.

---

## Notification Providers

The initial notification provider is **CallMeBot** for WhatsApp.

Providers are stored in:

```text
providers/
```

The active provider is selected with:

```bash
NOTIFY_PROVIDER="callmebot"
```

---

## Service Plugins

Each monitored service lives in:

```text
services/<service>/
```

A plugin normally contains:

```text
monitor.sh
recover.sh
service.conf.example
```

Every plugin follows the same monitor and recovery contracts.

---

## Current Status

EMPRETEL Sentinel is under active development.

The first production plugin will be **AzuraCast**, implemented entirely as an external service plugin without adding service-specific logic to the core.

---

## License

Released under the MIT License.
