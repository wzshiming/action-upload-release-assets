#!/usr/bin/env bash
set -e

function command_exists() {
  local COMMAND="$1"
  type "${COMMAND}" >/dev/null 2>&1
}

function upload() {
  if command_exists "./putingh"; then
    ./putingh $@
    return
  elif command_exists "putingh"; then
    putingh $@
    return
  else
    if [[ -z "${TAG}" ]]; then
      TAG="v0.2.0"
    fi

    if [[ -z "${GOOS}" ]]; then
      if [ "$(uname)" = "Darwin" ]; then
        GOOS="darwin"
      elif [ "$(uname -s)" == "Linux" ]; then
        GOOS="linux"
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

    NAME="putingh_${GOOS}_${GOARCH}"
    if [[ "${GOOS}" == "windows" ]]; then
      NAME="${NAME}.exe"
    fi

    TARGET="https://github.com/wzshiming/putingh/releases/download/${TAG}/${NAME}"

    echo "${TARGET}" -c -O putingh
    if command_exists wget; then
      wget "${TARGET}" -c -O putingh
    elif command_exists curl; then
      curl "${TARGET}" -o putingh
    else
      echo "No download tool available"
      exit 1
    fi

    chmod +x putingh
    ./putingh $@
  fi
}

if [[ -z "${RELEASE}" ]]; then
  RELEASE="release"
fi

if [[ -z "${SOURCE_PREFIX}" ]]; then
  REPO="$(git remote get-url --push origin | sed -e 's#https://github.com/##' | sed -e 's#git@github.com:##')"
  SOURCE_PREFIX="asset://${REPO}/$(git describe --tags)"
fi

for FILE in $(ls "${RELEASE}" | xargs)
do
  echo "Put ${RELEASE}/$FILE in ${SOURCE_PREFIX}/${FILE}"
  upload "${SOURCE_PREFIX}/${FILE}" "${RELEASE}/$FILE" || true
done