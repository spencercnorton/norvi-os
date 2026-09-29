## What changed

<!-- One paragraph. Link the issue if there is one: "Fixes #12". -->

## Why

## How it was tested

<!-- What you ran: Ubuntu and GNOME Shell versions, whether on a VM or a real machine, which installer and what you saw on the next boot or login. -->

## Checklist

- [ ] `python3 desktop/check_contrast.py`, `python3 desktop/check_gtk_css.py` and the `desktop/test-*.sh` scripts pass, and `shellcheck -S warning` is clean
- [ ] Commits are signed off (`git commit -s`, Developer Certificate of Origin)
- [ ] No secrets, hostnames, machine names, personal data or personal paths in the diff
- [ ] Every new change an installer makes is undone by the matching uninstall step
- [ ] Docs updated if behaviour changed (README, `docs/how-it-works.md`, `CHANGELOG.md`)

<!--
How this lands: a maintainer reviews the pull request here and merges it
once the required checks pass; it ships in the next tagged release. See
CONTRIBUTING.md and docs/RELEASING.md.
-->
