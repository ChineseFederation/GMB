#!/usr/bin/env bash
set -euo pipefail

base_ref="${BASE_REF:-origin/main}"

# 中文注释：GMB 是独立公开仓库，门禁不得依赖 CitizenConsole 私仓或 AI memory。
[[ -f shared/data-dictionary.json ]] || { echo "缺少公开数据字典。" >&2; exit 1; }
if [[ -e memory || -e citizenconsole || -e AGENTS.md || -e CODEX.md || -e CLAUDE.md ]]; then
  echo "GMB 根目录检测到私人 AI 或 CitizenConsole 残留。" >&2
  exit 1
fi

# 中文注释：全仓禁止中国国旗字符；用 UTF-8 八进制构造，避免规则本身成为命中项。
forbidden_cn_flag="$(printf '\360\237\207\250\360\237\207\263')"
flag_files="$(git grep --untracked -l -I -F "$forbidden_cn_flag" -- . || true)"
if [[ -n "$flag_files" ]]; then
  echo "检测到禁止使用的中国国旗字符（仅报告文件）：" >&2
  printf '  - %s\n' "$flag_files" >&2
  exit 1
fi

if ! git rev-parse --verify "$base_ref" >/dev/null 2>&1; then
  branch="${base_ref#origin/}"
  git fetch origin "$branch" --depth=1
fi

merge_base="$(git merge-base HEAD "$base_ref")"
declare -a changed_files=()
while IFS= read -r file; do
  [[ -n "$file" ]] && changed_files+=("$file")
done < <(git diff --name-only "$merge_base")
while IFS= read -r file; do
  [[ -n "$file" ]] && changed_files+=("$file")
done < <(git ls-files --others --exclude-standard)

if [[ "${#changed_files[@]}" -eq 0 ]]; then
  echo "未检测到变更文件，跳过公开仓库增量门禁。"
  exit 0
fi

# 中文注释：强特征机密扫描只报告路径，禁止把命中值写入 Actions 日志。
secret_files="$(git grep --untracked -l -I -E 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|AKIA[0-9A-Z]{16}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|sk_live_[A-Za-z0-9]{16,}' -- . ':!citizenapp/cloudflare/test/release_manifest.test.ts' ':!citizenweb/test/release_manifest.test.mjs' || true)"
if [[ -n "$secret_files" ]]; then
  echo "公开仓库检测到疑似真实机密（仅报告文件）：" >&2
  printf '  - %s\n' "$secret_files" >&2
  exit 1
fi

todo_word="TO""DO"
fixme_word="FIX""ME"
residual_regex="(console\\.log\\(|debugger;|dbg!\\(|todo!\\(|unimplemented!\\(|\\b${todo_word}\\b|\\b${fixme_word}\\b)"
version_regex='([A-Za-z0-9][._:-]v[0-9]+|/(api/)?v[0-9]+|[A-Za-z0-9]_V[0-9]+|schema_version|cache_version|protocol_version|tag[[:space:]]*=[[:space:]]*[\"]v[0-9]+)'
declare -a residual_hits=()
declare -a comment_hits=()
declare -a version_hits=()
declare -a lint_hits=()

is_code_file() {
  case "$1" in
    *.rs|*.dart|*.ts|*.tsx|*.js|*.jsx|*.mjs|*.sh|*.py|*.sql|*.swift|*.kt|*.kts) return 0 ;;
    *) return 1 ;;
  esac
}

skip_generated_or_vendor() {
  case "$1" in
    citizenapp/smoldotpow/*|citizenapp/assets/topup/walletconnect.bundle.js|citizenapp/cloudflare/worker-configuration.d.ts|*/dist/*|*/build/*|*/target/*|*/node_modules/*|*/GeneratedPluginRegistrant.*|*.g.dart|*.pb.dart|*.pbjson.dart|*.pbenum.dart|.github/scripts/repository-guardrails.sh) return 0 ;;
    *) return 1 ;;
  esac
}

sanitize_version_line() {
  local line="$1"
  # 中文注释：Apple 官方 API/audience 与四条产品正式 Release Tag 是外部接口或软件版本身份，
  # 不属于一方自定义协议标识；只精确移除这些已登记形态，继续阻断其它版本化协议。
  line="${line//QR_V1/}"
  line="${line//QrProtocol.qrV1/}"
  line="${line//QrProtocols.qrV1/}"
  line="${line//APK v2\/v3/}"
  line="${line//APK Signature Scheme v2\/v3/}"
  line="$(printf '%s\n' "$line" | sed -E \
    -e 's/Uuid::new_v[45]//g' \
    -e 's/arm64-v8a//g' \
    -e 's/armeabi-v7a//g' \
    -e 's/libbarhopper_v[0-9]+//g' \
    -e 's/RSASSA-PKCS1-v1_5//g' \
    -e 's/sc-rpc-spec-v2//g' \
    -e 's#https://api\.appstoreconnect\.apple\.com/v1##g' \
    -e 's/appstoreconnect-v1//g' \
    -e 's#/(upload/)?androidpublisher/v[0-9]+##g' \
    -e 's/citizen(app|wallet)-(ios|android)-v[0-9]+\.[0-9]+\.[0-9]+//g' \
    -e 's/citizen(app-cloudflare|web)-v[0-9]+\.[0-9]+\.[0-9]+//g')"
  printf '%s\n' "$line"
}

for file in "${changed_files[@]}"; do
  [[ -f "$file" ]] || continue
  is_code_file "$file" || continue
  skip_generated_or_vendor "$file" && continue

  added_lines="$(git diff --unified=0 "$merge_base" -- "$file" | grep -E '^\+' | grep -vE '^\+\+\+' || true)"
  [[ -n "$added_lines" ]] || continue

  # 中文注释：只拦本次新增残留；命令行工具的结果输出不是浏览器调试日志。
  if [[ "$file" != .github/scripts/*.mjs ]] && printf '%s\n' "$added_lines" | grep -Eq "$residual_regex"; then
    residual_hits+=("${file}: 本次新增内容含开发残留")
  fi

  added_count="$(printf '%s\n' "$added_lines" | sed '/^[[:space:]]*+?[[:space:]]*$/d' | wc -l | tr -d ' ')"
  if [[ "$added_count" -ge 12 ]] && ! printf '%s\n' "$added_lines" | grep -Eq '(//|/\*|\*|#).*[一-龥]'; then
    comment_hits+=("${file}: 新增 ${added_count} 行实现但没有中文注释")
  fi

  while IFS= read -r line; do
    sanitized="$(sanitize_version_line "$line")"
    if printf '%s\n' "$sanitized" | grep -Eq "$version_regex"; then
      version_hits+=("${file}: 新增非 QR_V1 的一方版本化标识")
      break
    fi
  done <<< "$added_lines"

  if [[ "$file" == *.rs ]] && printf '%s\n' "$added_lines" | grep -Eq '#!?\[allow\((dead_code|unused)'; then
    if ! printf '%s\n' "$added_lines" | grep -Eq '(//|/\*|\*|#).*[一-龥]'; then
      lint_hits+=("${file}: 新增编译器抑制但没有中文理由")
    fi
  fi
done

if [[ "${#residual_hits[@]}" -gt 0 ]]; then
  echo "检测到开发残留：" >&2
  printf '  - %s\n' "${residual_hits[@]}" >&2
  exit 1
fi
if [[ "${#comment_hits[@]}" -gt 0 ]]; then
  echo "检测到较大代码改动缺少中文注释：" >&2
  printf '  - %s\n' "${comment_hits[@]}" >&2
  exit 1
fi
if [[ "${#version_hits[@]}" -gt 0 ]]; then
  echo "检测到非 QR_V1 的一方版本化标识：" >&2
  printf '  - %s\n' "${version_hits[@]}" >&2
  exit 1
fi
if [[ "${#lint_hits[@]}" -gt 0 ]]; then
  echo "检测到缺少中文理由的编译器抑制：" >&2
  printf '  - %s\n' "${lint_hits[@]}" >&2
  exit 1
fi

echo "GMB 公开仓库门禁通过。"
