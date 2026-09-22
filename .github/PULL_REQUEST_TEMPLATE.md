## What changed

<!-- One paragraph. Link the issue if there is one: "Fixes #12". -->

## Why

## How it was tested

<!-- What you ran: Ubuntu and GNOME Shell versions, whether on a VM or a real machine, which installer and what you saw on the next boot or login. -->

## Checklist

- [ ] `python3 desktop/check_contrast.py` and both `desktop/test-*.sh` scripts pass, and `shellcheck -S warning` is clean
- [ ] Commits are signed off (`git commit -s`, Developer Certificate of Origin)
- [ ] No secrets, hostnames, machine names, personal data or personal paths in the diff
- [ ] Every new change an installer makes is undone by the matching uninstall step
- [ ] Docs updated if behaviour changed (README, `docs/how-it-works.md`, `CHANGELOG.md`)

<!--
How this lands: this repository is a release mirror. A maintainer reviews the
pull request here, applies accepted changes to the development tree, and the
change ships in the next tagged release — the pull request is then closed
with a reference to that release. See CONTRIBUTING.md.
-->
