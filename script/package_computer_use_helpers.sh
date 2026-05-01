#!/usr/bin/env bash
set -euo pipefail

HELPERS_DIR="${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}/Helpers"
BACKGROUND_HELPER_NAME="BackgroundComputerUseMCP"
MCP_PROXY_NAME="ClickyComputerUseMCPProxy"
MCP_PROXY_SOURCE="${PROJECT_DIR}/script/clicky_computer_use_mcp_proxy.swift"

swiftpm_configuration() {
  case "${CONFIGURATION:-Debug}" in
    Release) printf 'release\n' ;;
    *) printf 'debug\n' ;;
  esac
}

resolve_background_package_dir() {
  local candidates=()

  if [[ -n "${BACKGROUND_COMPUTER_USE_PACKAGE_DIR:-}" ]]; then
    candidates+=("${BACKGROUND_COMPUTER_USE_PACKAGE_DIR}")
  fi

  candidates+=(
    "${PROJECT_DIR}/../clicky-background-computer-use"
    "${PROJECT_DIR}/SourcePackages/checkouts/clicky-background-computer-use"
  )

  if [[ "${BUILD_DIR:-}" == *"/Build/"* ]]; then
    local derived_data_dir="${BUILD_DIR%%/Build/*}"
    candidates+=("${derived_data_dir}/SourcePackages/checkouts/clicky-background-computer-use")
  fi

  local derived_candidate
  while IFS= read -r derived_candidate; do
    candidates+=("${derived_candidate}")
  done < <(/usr/bin/find "${HOME}/Library/Developer/Xcode/DerivedData" \
    -path "*/SourcePackages/checkouts/clicky-background-computer-use/Package.swift" \
    2>/dev/null \
    | /usr/bin/sed 's#/Package.swift$##' \
    | /usr/bin/sort -u)

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}/Package.swift" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  printf 'Unable to locate clicky-background-computer-use. Set BACKGROUND_COMPUTER_USE_PACKAGE_DIR or resolve the Swift package in Xcode.\n' >&2
  return 1
}

sign_helper_if_needed() {
  local helper_path="$1"

  if [[ "${CODE_SIGNING_ALLOWED:-YES}" != "YES" ]]; then
    return 0
  fi

  if [[ -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" || "${EXPANDED_CODE_SIGN_IDENTITY}" == "-" ]]; then
    /usr/bin/codesign --force --sign - "${helper_path}"
    return 0
  fi

  /usr/bin/codesign --force \
    --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
    ${OTHER_CODE_SIGN_FLAGS:-} \
    "${helper_path}"
}

main() {
  /bin/mkdir -p "${HELPERS_DIR}"

  local package_dir
  package_dir="$(resolve_background_package_dir)"

  local spm_config
  spm_config="$(swiftpm_configuration)"

  local bin_path
  bin_path="$(cd "${package_dir}" && /usr/bin/swift build -c "${spm_config}" --show-bin-path)"
  (cd "${package_dir}" && /usr/bin/swift build -c "${spm_config}" --product "${BACKGROUND_HELPER_NAME}")

  /bin/cp "${bin_path}/${BACKGROUND_HELPER_NAME}" "${HELPERS_DIR}/${BACKGROUND_HELPER_NAME}"
  /usr/bin/xcrun swiftc \
    -sdk "${SDKROOT}" \
    -target "${NATIVE_ARCH_ACTUAL:-$(/usr/bin/arch)}-apple-macosx${MACOSX_DEPLOYMENT_TARGET}" \
    "${MCP_PROXY_SOURCE}" \
    -o "${HELPERS_DIR}/${MCP_PROXY_NAME}"

  /bin/chmod 755 "${HELPERS_DIR}/${BACKGROUND_HELPER_NAME}" "${HELPERS_DIR}/${MCP_PROXY_NAME}"
  sign_helper_if_needed "${HELPERS_DIR}/${BACKGROUND_HELPER_NAME}"
  sign_helper_if_needed "${HELPERS_DIR}/${MCP_PROXY_NAME}"

  printf 'Packaged computer-use helpers into %s\n' "${HELPERS_DIR}"
}

main "$@"
