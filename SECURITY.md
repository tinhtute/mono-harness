# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this repository, please report it
privately via [GitHub Security Advisories](https://github.com/tinhtute/monoharness/security/advisories/new)
(Security tab → "Report a vulnerability") rather than opening a public issue.

Please include:

- A description of the vulnerability and its potential impact
- Steps to reproduce, or a proof of concept
- Affected files, skills, or CLI commands

We aim to acknowledge reports within 5 business days.

## Scope

This repository contains agent skill definitions (Markdown instructions) and
a Go CLI (`cli/`). Security issues of interest include:

- Vulnerabilities in the `cli/` Go module (e.g. unsafe file handling, SQL
  injection into the local SQLite state, path traversal)
- Skill instructions that could cause an agent to leak secrets or perform
  unintended destructive actions
- Supply-chain issues in dependencies (see `cli/go.mod`)
