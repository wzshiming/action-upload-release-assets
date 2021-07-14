#!/usr/bin/env bash
set -e

function command_exists() {
  local COMMAND="$1"
  type "${COMMAND}" >/dev/null 2>&1
}

function hashsum() {
  if command_exists "sha256sum"; then
    sha256sum $@
  elif command_exists "shasum"; then
    shasum -a 256 $@
  fi
}

function upload() {
  BIN="putingh"
  if command_exists "./${BIN}"; then
    "./${BIN}" $@
    return
  elif command_exists "${BIN}"; then
    "${BIN}" $@
    return
  else
    if [[ -z "${TAG}" ]]; then
      TAG="v0.5.1"
    fi

    if [[ -z "${GOOS}" ]]; then
      if [[ "$(uname)" == "Darwin" ]]; then
        GOOS="darwin"
      elif [[ "$(uname -s)" == "Linux" ]]; then
        GOOS="linux"
      elif [[ "$(uname)" =~ "MINGW" ]]; then
        GOOS="windows"
      else
        echo "This system, $(uname), isn't supported"
        exit 1
      fi
    fi

    if [[ -z "${GOARCH}" ]]; then
      ARCH="$(uname -m)"
      case "${ARCH}" in
      x86_64 | amd64)
        GOARCH=amd64
        ;;
      armv8* | aarch64* | arm64)
        GOARCH=arm64
        ;;
      armv*)
        GOARCH=arm
        ;;
      i386 | i486 | i586 | i686)
        GOARCH=386
        ;;
      *)
        echo "This system's architecture, ${ARCH}, isn't supported"
        exit 1
        ;;
      esac
    fi

    NAME="${BIN}_${GOOS}_${GOARCH}"
    if [[ "${GOOS}" == "windows" ]]; then
      NAME="${NAME}.exe"
    fi

    TARGET="https://github.com/wzshiming/${BIN}/releases/download/${TAG}/${NAME}"

    EXEC="${BIN}"
    if [[ "${GOOS}" == "windows" ]]; then
      EXEC="${EXEC}.exe"
    fi

    if command_exists wget; then
      echo "wget ${TARGET}" -c -O "$EXEC"
      wget "${TARGET}" -c -O "$EXEC"
    elif command_exists curl; then
      echo "curl ${TARGET}" -L -o "$EXEC"
      curl "${TARGET}" -L -o "$EXEC"
    else
      echo "No download tool available"
      exit 1
    fi

    chmod +x "./$BIN"
    "./$BIN" $@
  fi
}

if [[ -z "${RELEASE}" ]]; then
  RELEASE="release"
fi

if [[ -z "${SOURCE_PREFIX}" ]]; then
  REPO="$(git remote get-url --push origin | sed -e 's#^https://github.com/##' | sed -e 's#^git@github.com:##')"
  SOURCE_PREFIX="asset://${REPO}/$(git describe --tags)"
fi

for FILE in $(ls "${RELEASE}" | xargs); do
  echo "Put ${RELEASE}/${FILE} in ${SOURCE_PREFIX}/${FILE}"
  upload "${SOURCE_PREFIX}/${FILE}" "${RELEASE}/${FILE}" || true
  hashsum "${RELEASE}/${FILE}" >"${RELEASE}/${FILE}".sha256 || true
  upload "${SOURCE_PREFIX}/${FILE}.sha256" "${RELEASE}/${FILE}.sha256" || true
  rm "${RELEASE}/${FILE}.sha256" || true
done
