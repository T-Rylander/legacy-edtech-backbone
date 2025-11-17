# Legacy EdTech Backbone - Copilot Instructions

## Project Context
This is an open-source edtech IT infrastructure project focused on repurposed hardware and zero-touch deployment workflows. The stack includes:
- Samba AD Domain Controller (Z390 hardware)
- PXE network boot server for mass imaging
- UniFi network infrastructure (Cloud Key, USG-3P, switches, APs)
- osTicket help desk on Raspberry Pi 5
- MkDocs documentation site

## Development Guidelines

### Documentation
- Use MkDocs with Material theme for all documentation
- Keep docs practical and hands-on (command examples, config snippets)
- Include hardware specs, decision rationale, and troubleshooting steps
- Write for sysadmins and edtech IT staff

### Scripts
- All scripts in `scripts/` should be bash with proper shebang (`#!/usr/bin/env bash`)
- Use environment variables from `.env` for secrets
- Include error handling and validation
- Add comments for complex logic
- Make scripts idempotent where possible

### Code Style
- Bash: Follow Google Shell Style Guide
- YAML: 2-space indentation
- Markdown: Use ATX-style headers (#)

### Security
- Never commit secrets, passwords, or API keys
- Use `.env.example` as template with placeholder values
- Document secret rotation procedures
- Include fail2ban and UFW configurations

### Testing
- GitHub Actions runs shellcheck on all bash scripts
- Test scripts on Ubuntu 24.04 LTS before committing
- Document manual test procedures in docs/

## Project Structure
- `docs/` - MkDocs source files
- `scripts/` - Executable bash automation scripts
- `.github/workflows/` - CI/CD pipelines
- `mkdocs.yml` - Documentation site configuration

## Target Audience
- Small MSPs pivoting to edtech
- School IT departments with limited budgets
- Technical users comfortable with CLI and Linux administration
