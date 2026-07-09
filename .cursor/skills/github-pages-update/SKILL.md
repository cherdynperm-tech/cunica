---
name: github-pages-update
description: Update GitHub Pages build and deploy automation safely. Use when the user asks to configure or troubleshoot GitHub Pages workflows, deployment triggers, or published docs paths.
disable-model-invocation: true
---

# GitHub Pages Update

## When to use

Use this skill for tasks related to GitHub Pages deployment workflows.

## Recommended workflow pattern

1. Build static content in CI.
2. Configure Pages with `actions/configure-pages`.
3. Upload artifact with `actions/upload-pages-artifact`.
4. Deploy with `actions/deploy-pages`.

## Minimum permissions

- `pages: write`
- `id-token: write`

## Authoring checklist

- Keep deployment trigger explicit (`push` and/or `workflow_dispatch`).
- Keep build output path explicit in the workflow.
- Document where published files come from.
- Avoid deprecated Pages actions.

## Post-change checks

- Verify workflow completes without manual intervention.
- Verify published site opens and static paths resolve.
- Verify docs mention deployment trigger and expected output directory.
