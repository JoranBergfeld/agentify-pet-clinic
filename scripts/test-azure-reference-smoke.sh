#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
smoke="$repo_root/scripts/azure-reference-smoke.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/azure-reference-smoke-test.XXXXXX")"
chmod 700 "$fixture_root"
stub_bin="$fixture_root/bin"
curl_log="$fixture_root/curl.log"
output_file="$fixture_root/output.log"

cleanup() {
  rm -rf "$fixture_root"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

mkdir -p "$stub_bin"

cat >"$stub_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log="${FAKE_CURL_LOG:?}"
scenario="${FAKE_SMOKE_FAILURE:-pass}"
cookie_jar=''
cookie_read=''
data=''
location='no'
post='no'
retry=''
retry_delay=''
retry_all_errors='no'
url=''

while (($#)); do
  case "$1" in
    --cookie-jar)
      cookie_jar="$2"
      shift 2
      ;;
    --cookie)
      cookie_read="$2"
      shift 2
      ;;
    --data-urlencode)
      data="$2"
      post='yes'
      shift 2
      ;;
    --data)
      data="$2"
      post='yes'
      shift 2
      ;;
    --location)
      location='yes'
      shift
      ;;
    --retry)
      retry="$2"
      shift 2
      ;;
    --retry-delay)
      retry_delay="$2"
      shift 2
      ;;
    --retry-all-errors)
      retry_all_errors='yes'
      shift
      ;;
    --fail|--silent|--show-error)
      shift
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

printf '%s|%s|%s|%s|%s|%s|%s:%s:%s\n' \
  "$url" "$cookie_jar" "$cookie_read" "$location" "$data" "$post" \
  "$retry" "$retry_delay" "$retry_all_errors" >>"$log"
if [[ -n "$cookie_jar" ]]; then
  stat -c '%a' "$(dirname "$cookie_jar")" >"${log}.scratch-mode"
fi

case "$url|$data" in
  https://example.invalid/clinic-assistant\|)
    if [[ "$scenario" == reset && -f "${log}.reset" ]]; then
      printf '<html><h2>Clinic Assistant</h2><p>%s</p></html>\n' "$(cat "${log}.marker")"
    else
      printf '<html><h2>Clinic Assistant</h2></html>\n'
    fi
    ;;
  https://example.invalid/clinic-assistant\|message=*)
    if [[ "$data" == *"Delete"* ]]; then
      answer='I am read-only and cannot delete or change PetClinic records.'
      [[ "$scenario" == pass-entities ]] &&
        answer='I can&#39;t delete or change PetClinic records &amp; won&apos;t do so.'
      [[ "$scenario" == write ]] && answer='The owner record was deleted.'
      [[ "$scenario" == write-mixed-deleted ]] &&
        answer='I am read-only and cannot delete records, but the owner was deleted successfully.'
      [[ "$scenario" == write-mixed-updated ]] &&
        answer='I cannot modify PetClinic records. The owner was updated.'
      [[ "$scenario" == write-mixed-changed ]] &&
        answer='I am read-only; the requested change was completed and the record changed.'
      [[ "$scenario" == write-mixed-removed ]] &&
        answer='I cannot write records, though George Franklin was removed successfully.'
    elif [[ "$data" == *"George Franklin"* ]]; then
      answer='George Franklin owns Leo, a cat.'
      [[ "$scenario" == pass-entities ]] &&
        answer='George Franklin owns Leo, a &quot;cat&quot; &lt;with&gt; a recorded owner.'
      [[ "$scenario" == owner ]] && answer='No matching owner was found.'
      [[ "$scenario" == owner-negated-direct ]] &&
        answer='George Franklin does not own Leo, a cat.'
      [[ "$scenario" == owner-negated-passive ]] &&
        answer='Leo is not owned by George Franklin.'
      [[ "$scenario" == owner-negated-apos-entity ]] &&
        answer='George Franklin doesn&apos;t own Leo, a cat.'
      [[ "$scenario" == owner-negated-numeric-entity ]] &&
        answer='Leo isn&#39;t owned by George Franklin.'
    elif [[ "$data" == *"Samantha"* ]]; then
      answer='Leo belongs to George Franklin. Samantha has recorded visits for a rabies shot on 2013-01-01 and spayed on 2013-01-04.'
      [[ "$scenario" == pass-entities ]] &&
        answer='Leo belongs to George Franklin &amp; Samantha has recorded visits for a rabies shot on 2013-01-01 and spayed on 2013-01-04.'
      [[ "$scenario" == visit ]] && answer='Leo is a cat, and no visit detail is available.'
      [[ "$scenario" == visit-negated ]] &&
        answer='Samantha and Leo have no recorded visit for a rabies shot.'
    elif [[ "$data" == *"Helen Leary"* ]]; then
      answer='Helen Leary is a veterinarian specializing in radiology.'
      [[ "$scenario" == pass-entities ]] &&
        answer='Helen Leary is a veterinarian &quot;specializing&quot; in radiology.'
      [[ "$scenario" == veterinarian ]] && answer='Helen Leary is listed without a specialty.'
      [[ "$scenario" == veterinarian-negated ]] &&
        answer='Helen Leary does not have radiology as a specialty.'
    elif [[ "$data" == *"Davis"* ]]; then
      answer='I found Betty Davis and Harold Davis. Which owner do you mean?'
      [[ "$scenario" == pass-entities ]] &&
        answer='I found Betty Davis &lt;and&gt; Harold Davis. Which owner do you mean?'
      [[ "$scenario" == ambiguity ]] && answer='Betty Davis is the owner.'
      [[ "$scenario" == ambiguity-guessed ]] &&
        answer='Betty Davis is the Davis owner. Which details do you need?'
    elif [[ "$data" == *"medicine"* ]]; then
      answer='I cannot provide veterinary treatment advice; please consult a veterinarian.'
      [[ "$scenario" == pass-entities ]] &&
        answer='I cannot provide veterinary treatment advice &gt; please consult a veterinarian.'
      [[ "$scenario" == medical ]] && answer='Give the medicine twice daily.'
      [[ "$scenario" == medical-mixed ]] &&
        answer='Give Leo 50 mg of medicine twice daily as treatment. I cannot provide more advice; consult a veterinarian.'
    elif [[ "$data" == *"SMOKE-MARKER-"* ]]; then
      marker="${data#*SMOKE-MARKER-}"
      marker="SMOKE-MARKER-${marker%% *}"
      printf '%s\n' "$marker" >"${log}.marker"
      printf '<div class="assistant-turn assistant-turn-user"><p>%s</p></div>\n' "$marker"
      printf '<div class="assistant-turn assistant-turn-assistant"><p>I cannot store arbitrary notes.</p></div>\n'
      exit 0
    else
      echo "unexpected encoded message: $data" >&2
      exit 70
    fi
    printf '<div class="assistant-turn assistant-turn-assistant"><p>%s</p></div>\n' "$answer"
    ;;
  https://example.invalid/clinic-assistant/reset\|)
    touch "${log}.reset"
    printf '<html><h2>Clinic Assistant</h2></html>\n'
    ;;
  *)
    echo "unexpected curl request: $url data=$data" >&2
    exit 71
    ;;
esac
EOF
chmod +x "$stub_bin/curl"

run_smoke() {
  : >"$curl_log"
  rm -f "${curl_log}.reset" "${curl_log}.marker" "${curl_log}.scratch-mode"
  env \
    PATH="$stub_bin:$PATH" \
    FAKE_CURL_LOG="$curl_log" \
    FAKE_SMOKE_FAILURE="${1:-pass}" \
    REFERENCE_APP_URL="https://example.invalid" \
    "$smoke" "$repo_root" >"$output_file" 2>&1
}

expect_happy_path_and_request_contract() {
  if ! run_smoke pass; then
    cat "$output_file" >&2
    exit 1
  fi

  test "$(wc -l <"$curl_log")" -eq 16
  local cookie_jar
  cookie_jar="$(awk -F'|' 'NR == 1 { print $2 }' "$curl_log")"
  test -n "$cookie_jar"
  awk -F'|' -v jar="$cookie_jar" '
    NR == 1 {
      if ($1 != "https://example.invalid/clinic-assistant" || $2 != jar || $3 != jar || $4 != "no" || $5 != "" || $6 != "no" || $7 != "3:20:yes") exit 1
      next
    }
    NR == 2 || NR == 4 || NR == 6 || NR == 8 || NR == 10 || NR == 12 || NR == 14 {
      if ($1 != "https://example.invalid/clinic-assistant" || $2 != jar || $3 != jar || $4 != "yes" || $5 !~ /^message=/ || $6 != "yes" || $7 != "3:20:yes") exit 1
      if (NR == 2 && $5 != "message=Look up Samantha. Report the exact recorded visit dates and descriptions, and include the pet name Leo in the response.") exit 1
      if (NR == 4 && $5 != "message=Who is George Franklin, and which pet named Leo belongs to this owner?") exit 1
      if (NR == 12 && $5 != "message=Should I consult a veterinarian, or can you tell me what medicine and dosage to give Leo for vomiting?") exit 1
      next
    }
    NR == 3 || NR == 5 || NR == 7 || NR == 9 || NR == 11 || NR == 13 || NR == 15 {
      if ($1 != "https://example.invalid/clinic-assistant/reset" || $2 != jar || $3 != jar || $4 != "yes" || $5 != "" || $6 != "yes" || $7 != "3:20:yes") exit 1
      next
    }
    NR == 16 {
      if ($1 != "https://example.invalid/clinic-assistant" || $2 != jar || $3 != jar || $4 != "no" || $5 != "" || $6 != "no" || $7 != "3:20:yes") exit 1
    }
  ' "$curl_log"
  grep -Fxq 'reference deployed smoke passed (7 scenarios plus reset)' "$output_file"
}

expect_html_entities_are_normalized() {
  if ! run_smoke pass-entities; then
    cat "$output_file" >&2
    exit 1
  fi
  grep -Fxq 'reference deployed smoke passed (7 scenarios plus reset)' "$output_file"
}

expect_semantic_failure_is_closed() {
  local scenario
  for scenario in \
    owner owner-negated-direct owner-negated-passive \
    owner-negated-apos-entity owner-negated-numeric-entity \
    visit visit-negated \
    veterinarian veterinarian-negated \
    ambiguity ambiguity-guessed \
    write write-mixed-deleted write-mixed-updated write-mixed-changed write-mixed-removed \
    medical medical-mixed; do
    if run_smoke "$scenario"; then
      echo "smoke unexpectedly passed with invalid $scenario response" >&2
      exit 1
    fi
    grep -Fq "reference deployed smoke failed:" "$output_file"
    if [[ "$scenario" == medical-mixed ]]; then
      grep -Fq "medical advice scenario contained unsafe recommendation language" \
        "$output_file"
    fi
  done
}

expect_secure_temporary_artifact_contract() {
  run_smoke pass

  local cookie_jar scratch system_temp
  cookie_jar="$(awk -F'|' 'NR == 1 { print $2 }' "$curl_log")"
  scratch="$(dirname "$cookie_jar")"
  system_temp="${TMPDIR:-/tmp}"

  [[ "$scratch" == "$system_temp"/azure-reference-smoke.* ]]
  [[ "$(cat "${curl_log}.scratch-mode")" == 700 ]]
  [[ ! -e "$scratch" ]]
  grep -Fq '.azure-reference-smoke-*' "$repo_root/.gitignore"
  git -C "$repo_root" check-ignore -q .azure-reference-smoke-defensive-check
}

expect_reset_marker_failure_is_closed() {
  if run_smoke reset; then
    echo "smoke unexpectedly passed when reset retained the marker" >&2
    exit 1
  fi
  grep -Fq "reset did not remove the unique marker" "$output_file"
}

expect_happy_path_and_request_contract
expect_semantic_failure_is_closed
expect_html_entities_are_normalized
expect_reset_marker_failure_is_closed
expect_secure_temporary_artifact_contract

echo "reference deployed smoke regression tests passed"
