#!/usr/bin/env bats

setup() {
	repo_root="${BATS_TEST_DIRNAME}/.."
	test_tmp="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp.XXXXXX")"
	build_dir="${test_tmp}/build"
	cache_dir="${test_tmp}/cache"
	env_dir="${test_tmp}/env"
	stub_bin_dir="${test_tmp}/bin"

	mkdir -p "${build_dir}" "${cache_dir}" "${env_dir}" "${stub_bin_dir}"
	rm -f "${repo_root}/export"
}

teardown() {
	rm -f "${repo_root}/export"
	rm -rf "${test_tmp}"
}

write_pyproject_with_uv_index() {
	local header="${1:-[[tool.uv.index]]}"

	cat >"${build_dir}/pyproject.toml" <<EOF
${header}
name = "codeartifact"
url = "https://example.invalid/simple/"
EOF
}

write_pyproject_without_uv_index() {
	cat >"${build_dir}/pyproject.toml" <<'EOF'
[project]
name = "example"
version = "0.1.0"
EOF
}

write_env_file() {
	local name="${1}"
	local value="${2}"

	printf '%s' "${value}" >"${env_dir}/${name}"
}

write_aws_stub() {
	cat >"${stub_bin_dir}/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' 'stub-token-123'
EOF
	chmod +x "${stub_bin_dir}/aws"
}

@test "detect succeeds when pyproject.toml contains a uv index block" {
	write_pyproject_with_uv_index

	run "${repo_root}/bin/detect" "${build_dir}"

	[ "${status}" -eq 0 ]
	[ "${output}" = "AWS CodeArtifact uv auth" ]
}

@test "detect succeeds when uv index header contains valid TOML whitespace" {
	write_pyproject_with_uv_index "[[ tool.uv.index ]]"

	run "${repo_root}/bin/detect" "${build_dir}"

	[ "${status}" -eq 0 ]
	[ "${output}" = "AWS CodeArtifact uv auth" ]
}

@test "detect succeeds when uv index header is indented" {
	write_pyproject_with_uv_index "  [[tool.uv.index]]"

	run "${repo_root}/bin/detect" "${build_dir}"

	[ "${status}" -eq 0 ]
	[ "${output}" = "AWS CodeArtifact uv auth" ]
}

@test "detect fails when pyproject.toml is missing" {
	run "${repo_root}/bin/detect" "${build_dir}"

	[ "${status}" -eq 1 ]
}

@test "detect fails when pyproject.toml has no uv index block" {
	write_pyproject_without_uv_index

	run "${repo_root}/bin/detect" "${build_dir}"

	[ "${status}" -eq 1 ]
}

@test "compile succeeds without AWS_CODEARTIFACT_REPOSITORY" {
	write_pyproject_with_uv_index
	write_aws_stub
	write_env_file "AWS_CODEARTIFACT_DOMAIN" "example"
	write_env_file "AWS_CODEARTIFACT_DOMAIN_OWNER" "123456789012"
	write_env_file "AWS_CODEARTIFACT_REGION" "us-east-1"

	PATH="${stub_bin_dir}:${PATH}" run "${repo_root}/bin/compile" "${build_dir}" "${cache_dir}" "${env_dir}"

	[ "${status}" -eq 0 ]
	[ -f "${repo_root}/export" ]
}

@test "compile fails when aws CLI is unavailable" {
	write_pyproject_with_uv_index
	write_env_file "AWS_CODEARTIFACT_DOMAIN" "example"
	write_env_file "AWS_CODEARTIFACT_DOMAIN_OWNER" "123456789012"
	write_env_file "AWS_CODEARTIFACT_REGION" "us-east-1"

	PATH="/usr/bin:/bin" run "${repo_root}/bin/compile" "${build_dir}" "${cache_dir}" "${env_dir}"

	[ "${status}" -eq 1 ]
	[[ "${output}" == *"AWS CLI is required but was not found on PATH"* ]]
}

@test "compile writes uv exports using the default index name" {
	write_pyproject_with_uv_index
	write_aws_stub
	write_env_file "AWS_CODEARTIFACT_DOMAIN" "example"
	write_env_file "AWS_CODEARTIFACT_DOMAIN_OWNER" "123456789012"
	write_env_file "AWS_CODEARTIFACT_REGION" "us-east-1"

	PATH="${stub_bin_dir}:${PATH}" run "${repo_root}/bin/compile" "${build_dir}" "${cache_dir}" "${env_dir}"

	[ "${status}" -eq 0 ]
	[ -f "${repo_root}/export" ]
	run grep -F "export UV_INDEX_CODEARTIFACT_USERNAME=aws" "${repo_root}/export"
	[ "${status}" -eq 0 ]
	run grep -F "export UV_INDEX_CODEARTIFACT_PASSWORD=stub-token-123" "${repo_root}/export"
	[ "${status}" -eq 0 ]
}

@test "compile accepts uv index headers with valid TOML whitespace" {
	write_pyproject_with_uv_index "[[ tool.uv.index ]]"
	write_aws_stub
	write_env_file "AWS_CODEARTIFACT_DOMAIN" "example"
	write_env_file "AWS_CODEARTIFACT_DOMAIN_OWNER" "123456789012"
	write_env_file "AWS_CODEARTIFACT_REGION" "us-east-1"

	PATH="${stub_bin_dir}:${PATH}" run "${repo_root}/bin/compile" "${build_dir}" "${cache_dir}" "${env_dir}"

	[ "${status}" -eq 0 ]
	[ -f "${repo_root}/export" ]
}

@test "compile normalizes custom index names" {
	write_pyproject_with_uv_index
	write_aws_stub
	write_env_file "AWS_CODEARTIFACT_DOMAIN" "example"
	write_env_file "AWS_CODEARTIFACT_DOMAIN_OWNER" "123456789012"
	write_env_file "AWS_CODEARTIFACT_REGION" "us-east-1"
	write_env_file "UV_CODEARTIFACT_INDEX_NAME" "private-prod"

	PATH="${stub_bin_dir}:${PATH}" run "${repo_root}/bin/compile" "${build_dir}" "${cache_dir}" "${env_dir}"

	[ "${status}" -eq 0 ]
	run grep -F "export UV_INDEX_PRIVATE_PROD_USERNAME=aws" "${repo_root}/export"
	[ "${status}" -eq 0 ]
	run grep -F "export UV_INDEX_PRIVATE_PROD_PASSWORD=stub-token-123" "${repo_root}/export"
	[ "${status}" -eq 0 ]
}
