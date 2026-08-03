# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability, report it responsibly.

### How to Report

1. **DO NOT** open a public GitHub issue
2. Email the maintainers via GitHub Security Advisories
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- Acknowledgment within 48 hours
- Regular updates on the investigation
- Credit for responsible disclosure (unless you prefer to remain anonymous)

### Scope

In scope:
- NanoAI Runtime core (`nanortime-core`)
- Official integrations (tools, LoRAs, etc.)
- Official documentation
- CI/CD pipeline configuration

Out of scope:
- Third-party integrations
- User-configured tools
- Models downloaded from third parties
- llama.cpp upstream vulnerabilities (report to their project)

## Security Best Practices

### For Users

1. **Keep NanoAI Updated**: Always use the latest version
2. **Review Tools**: Review JSON tool definitions before using them
3. **Limit API Access**: Use API keys with minimal permissions
4. **Monitor Logs**: Check logs for unusual activity
5. **Use Environment Variables**: Never hardcode API keys in config files

### For Developers

1. **Prefer Safe Rust**: Avoid `unsafe` blocks when possible
2. **Validate Inputs**: Always validate user inputs at boundaries
3. **Sanitize Outputs**: Sanitize outputs before displaying to users
4. **Keep Dependencies Updated**: Run `cargo update` regularly
5. **Run Clippy**: `cargo clippy -- -D warnings` before committing

## Dependency Verification

All Rust dependencies are sourced from crates.io with checksum verification by Cargo.
Dual-licensed (MIT/Apache-2.0) dependencies are compatible with our MIT license.

## Security Audits

Security audits will be conducted prior to major releases. Results will be published
in `docs/security/`.
