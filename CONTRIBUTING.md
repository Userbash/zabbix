# Contributing

Found a bug? Have an idea? Just want to help? Great - contributions are welcome.

## Reporting Issues

If something's broken, open an issue and tell us:

- What OS you're on
- What version you're running
- Exact steps to make it happen again
- What you expected vs what actually happened

## Contributing Code

Fork the repo, make a branch, fix it, and send a pull request.

```bash
git clone https://github.com/yourusername/zabbix-podman.git
cd zabbix-podman
git checkout -b feature/whatever-you-are-fixing
```

Make your changes. Test locally:

```bash
bash scripts/rebuild-from-scratch.sh
podman ps
# Make sure it works
```

Clean up afterward:

```bash
podman-compose down -v
```

Commit with a clear message:

```
Add: describe what you did

Longer explanation if needed.
Fixes #123 if you're fixing a specific issue
```

Push to your fork and open a pull request. Link any related issues and describe what you changed.

## Keep It Simple

- For bash: use `set -euo pipefail` at the top
- YAML gets 2-space indents
- In comments, explain why not what
- Constants in UPPERCASE

## Documenting Your Change

If you add something new:

- Update README with how to use it
- Add comments to non-obvious code
- Update docker-compose.yaml if needed

## Questions?

Check the [Issues](https://github.com/yourusername/zabbix-podman/issues) page first - someone else might've asked it. If not, ask away.

## 📋 Pull Request Checklist

- [ ] Forked and branched correctly
- [ ] Changes tested locally
- [ ] No breaking changes (or documented)
- [ ] Documentation updated
- [ ] Commit messages are clear
- [ ] No sensitive data committed
- [ ] License header added (if new file)

## 📜 License

By contributing, you agree your changes are licensed under [MIT License](LICENSE).

## 💬 Questions?

- 📧 Email maintainers
- 💻 Open a discussion
- 🐛 Check existing issues first

**Thank you for making this project better! 🙏**
