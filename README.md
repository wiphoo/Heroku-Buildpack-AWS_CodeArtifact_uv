# AWS CodeArtifact for `uv`

Cloud Native Buildpack that fetches an AWS CodeArtifact token during build and
exposes it to downstream build steps using `uv` named-index environment
variables.

This buildpack is intended for Python apps that install private packages from
AWS CodeArtifact with `uv`.

## What it exports

During `bin/compile`, the buildpack writes an `export` script that sets:

- `UV_INDEX_<NORMALIZED_NAME>_USERNAME=aws`
- `UV_INDEX_<NORMALIZED_NAME>_PASSWORD=<token>`

Example normalization:

- `codeartifact` -> `UV_INDEX_CODEARTIFACT_USERNAME`
- `private-prod` -> `UV_INDEX_PRIVATE_PROD_USERNAME`

AWS credentials must already be available to the AWS CLI during build.

## Required config vars

- `AWS_CODEARTIFACT_DOMAIN`
- `AWS_CODEARTIFACT_DOMAIN_OWNER`
- `AWS_CODEARTIFACT_REGION`

## Optional config vars

- `UV_CODEARTIFACT_INDEX_NAME`
  - Default: `codeartifact`
  - Set this explicitly so it matches the named index in your
    `pyproject.toml`

## `pyproject.toml` example

```toml
[[tool.uv.index]]
name = "codeartifact"
url = "https://example.invalid/pypi/private/simple/"
default = false

[project]
name = "example-app"
version = "0.1.0"
dependencies = ["private-package"]
```

The buildpack only handles authentication. Your named `uv` index definition
still belongs in `pyproject.toml`.

## Local `pack build` usage

Example:

```bash
pack build example-app \
  --path /path/to/app \
  --builder heroku/builder:24 \
  --buildpack /path/to/Heroku-Buildpack-AWS_CodeArtifact_UV \
  --env AWS_CODEARTIFACT_DOMAIN=example \
  --env AWS_CODEARTIFACT_DOMAIN_OWNER=123456789012 \
  --env AWS_CODEARTIFACT_REGION=us-east-1
```

For deterministic local testing without real AWS access, the integration
harness uses the test-only environment override
`BUILDPACK_TEST_AWS_CODEARTIFACT_TOKEN`.

## Local development

Requirements:

- `shellcheck`
- `shfmt`
- `bats`
- `pack`
- `docker`

Commands:

```bash
make
make tools
make check
make lint
make test
make test-integration-generic
make test-integration-heroku
make ci
```
