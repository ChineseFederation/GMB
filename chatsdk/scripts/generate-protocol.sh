#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
protocol_dir="$root/lib/src/protocol"

command -v protoc >/dev/null 2>&1 || {
  printf '%s\n' 'protoc is required' >&2
  exit 1
}
command -v protoc-gen-dart >/dev/null 2>&1 || {
  printf '%s\n' 'protoc-gen-dart is required' >&2
  exit 1
}

protoc \
  --proto_path="$protocol_dir" \
  --dart_out="$protocol_dir" \
  "$protocol_dir/basic_content.proto" \
  "$protocol_dir/media_content.proto" \
  "$protocol_dir/message.proto" \
  "$protocol_dir/attachment.proto" \
  "$protocol_dir/chat_frame.proto"
