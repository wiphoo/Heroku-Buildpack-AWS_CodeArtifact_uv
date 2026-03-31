#!/usr/bin/env bash

set -euo pipefail

readonly UV_INDEX_HEADER_PATTERN='^[[:space:]]*\[\[[[:space:]]*tool\.uv\.index[[:space:]]*\]\]'
readonly TEST_TOKEN_ENV_VAR="BUILDPACK_TEST_AWS_CODEARTIFACT_TOKEN"

log() {
	echo "-----> $*"
}

log_error() {
	echo "-----> $*" >&2
}

app_has_uv_index() {
	local app_dir="${1:?app directory is required}"

	[[ -f "${app_dir}/pyproject.toml" ]] || return 1
	grep -Eq "${UV_INDEX_HEADER_PATTERN}" "${app_dir}/pyproject.toml"
}

normalize_index_name() {
	local raw_name="${1:?index name is required}"

	printf '%s' "${raw_name}" |
		tr '[:lower:]' '[:upper:]' |
		sed -E 's/[^A-Z0-9]+/_/g; s/^_+//; s/_+$//'
}

require_env() {
	local var_name="${1:?variable name is required}"

	if [[ -z "${!var_name:-}" ]]; then
		log_error "Missing required config var: ${var_name}"
		return 1
	fi
}

load_env_dir() {
	local env_dir="${1:?env directory is required}"

	[[ -d "${env_dir}" ]] || return 0

	while IFS= read -r -d '' env_file; do
		local varname value
		varname="$(basename "${env_file}")"
		value="$(<"${env_file}")"
		export "${varname}=${value}"
	done < <(find "${env_dir}" -maxdepth 1 -type f -print0)
}

fetch_codeartifact_token() {
	if [[ "${!TEST_TOKEN_ENV_VAR+x}" == "x" ]]; then
		printf '%s' "${!TEST_TOKEN_ENV_VAR}"
		return 0
	fi

	if ! command -v aws >/dev/null 2>&1; then
		log_error "AWS CLI is required but was not found on PATH"
		return 1
	fi

	require_env "AWS_CODEARTIFACT_DOMAIN" || return 1
	require_env "AWS_CODEARTIFACT_DOMAIN_OWNER" || return 1
	require_env "AWS_CODEARTIFACT_REGION" || return 1

	aws codeartifact get-authorization-token \
		--domain "${AWS_CODEARTIFACT_DOMAIN}" \
		--domain-owner "${AWS_CODEARTIFACT_DOMAIN_OWNER}" \
		--region "${AWS_CODEARTIFACT_REGION}" \
		--query authorizationToken \
		--output text
}

write_export_script() {
	local destination="${1:?destination is required}"
	local normalized_index_name="${2:?normalized index name is required}"
	local token="${3:?token is required}"

	{
		printf '#!/usr/bin/env bash\n'
		printf 'export UV_INDEX_%s_USERNAME=%q\n' "${normalized_index_name}" "aws"
		printf 'export UV_INDEX_%s_PASSWORD=%q\n' "${normalized_index_name}" "${token}"
	} >"${destination}"

	chmod +x "${destination}"
}

validate_token() {
	local token="${1:-}"

	if [[ -z "${token}" || "${token}" == "None" ]]; then
		log_error "Failed to fetch a valid AWS CodeArtifact authorization token"
		return 1
	fi
}
