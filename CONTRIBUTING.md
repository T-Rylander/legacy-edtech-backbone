# CONTRIBUTING.md

## Contributing to Legacy EdTech Backbone

Thank you for your interest in contributing! This project welcomes contributions from the community.

## Code Style

### Bash Scripts
- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use `#!/usr/bin/env bash` shebang
- Include error handling with `set -euo pipefail`
- Add comments for complex logic
- Make scripts idempotent where possible

### Documentation
- Use Markdown with ATX-style headers (#)
- Include practical examples and command snippets
- Test all commands before documenting
- Keep language clear and concise

### YAML
- 2-space indentation
- Use quotes for strings with special characters
- Validate with yamllint

## Development Workflow

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Test scripts on Ubuntu 24.04 LTS
   - Run shellcheck locally: `shellcheck scripts/*.sh`
   - Build docs: `mkdocs serve`

4. **Commit with descriptive messages**
   ```bash
   git commit -m "type: brief description

   Longer explanation if needed"
   ```
   
   Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`

5. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```

## Testing

### Scripts
- Test all scripts on fresh Ubuntu 24.04 LTS VM
- Verify error handling (try with invalid inputs)
- Check idempotency (run twice, verify second run is safe)

### Documentation
- Build with `mkdocs build --strict`
- Check for broken links
- Verify all commands execute successfully

## Security

- Never commit secrets or passwords
- Use `.env.example` as template
- Report security issues privately via GitHub Security tab
- Follow principle of least privilege

## Pull Request Guidelines

- One feature/fix per PR
- Include tests if adding new scripts
- Update documentation if changing behavior
- Reference related issues with `Fixes #123`

## Community Guidelines

- Be respectful and constructive
- Help others in issues and discussions
- Share your deployment experiences
- Credit others' work and projects

## Questions?

- Open an issue for bugs or feature requests
- Start a discussion for questions
- Check [Troubleshooting guide](docs/10-troubleshooting.md) first

Thank you for contributing! 🚀
