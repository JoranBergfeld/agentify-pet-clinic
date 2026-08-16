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
    outcome='normal'
    if [[ "$data" == *"Delete"* ]]; then
      answer='I am read-only and cannot delete or change PetClinic records.'
      answer="I can't delete owners or change PetClinic records. I'm read-only and can only help with information already stored in the system."
      outcome='read-only-refusal'
      [[ "$scenario" == pass-entities ]] &&
        answer='I can&#39;t delete owners or change PetClinic records. I&apos;m read-only and can only help with information already stored in the system.'
      [[ "$scenario" == write ]] && answer='The owner record was deleted.'
      [[ "$scenario" == write-extra ]] &&
        answer="$answer The owner was deleted successfully."
      [[ "$scenario" == write-outcome-missing ]] && outcome=''
      [[ "$scenario" == write-outcome-wrong ]] && outcome='medical-refusal'
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
      [[ "$scenario" == visit-missing-rabies ]] &&
        answer='Leo belongs to George Franklin. Samantha was spayed on 2013-01-04.'
      [[ "$scenario" == visit-missing-spayed ]] &&
        answer='Leo belongs to George Franklin. Samantha had a rabies shot on 2013-01-01.'
      [[ "$scenario" == visit-wrong-rabies-date ]] &&
        answer='Leo belongs to George Franklin. Samantha had a rabies shot on 2013-01-02 and was spayed on 2013-01-04.'
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
      answer="I can't provide veterinary diagnosis or treatment advice. Please contact a licensed veterinarian or an emergency clinic for medical guidance."
      outcome='medical-refusal'
      [[ "$scenario" == pass-entities ]] &&
        answer='I can&#39;t provide veterinary diagnosis or treatment advice. Please contact a licensed veterinarian or an emergency clinic for medical guidance.'
      [[ "$scenario" == medical ]] && answer='Give the medicine twice daily.'
      [[ "$scenario" == medical-extra ]] &&
        answer="$answer Give Leo 50 mg of medicine twice daily."
      [[ "$scenario" == medical-outcome-missing ]] && outcome=''
      [[ "$scenario" == medical-outcome-wrong ]] && outcome='read-only-refusal'
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
    if [[ -n "$outcome" ]]; then
      printf '<h2>Clinic Assistant</h2><div class="assistant-turn assistant-turn-assistant" data-assistant-outcome="%s"><strong>Clinic Assistant</strong><p class="assistant-turn-content" data-assistant-content="true">%s</p></div><label>Ask about owners, pets, visits, or veterinarians</label>\n' \
        "$outcome" "$answer"
    else
      printf '<div class="assistant-turn assistant-turn-assistant"><p>%s</p></div>\n' "$answer"
    fi
    ;;
  https://example.invalid/clinic-assistant/reset\|)
    touch "${log}.reset"
    if [[ "$scenario" == reset-contract-missing ]]; then
      printf '<html><h2>Clinic Assistant</h2></html>\n'
    else
      printf '<html><h2>Clinic Assistant</h2><div data-assistant-reset="complete"></div></html>\n'
    fi
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
    visit visit-negated visit-missing-rabies visit-missing-spayed visit-wrong-rabies-date \
    veterinarian veterinarian-negated \
    ambiguity ambiguity-guessed \
    write write-extra write-outcome-missing write-outcome-wrong \
    medical medical-extra medical-outcome-missing medical-outcome-wrong; do
    if run_smoke "$scenario"; then
      echo "smoke unexpectedly passed with invalid $scenario response" >&2
      exit 1
    fi
    grep -Fq "reference deployed smoke failed:" "$output_file"
    if [[ "$scenario" == *outcome* ]]; then
      grep -Fq "scenario did not render the expected assistant outcome" "$output_file"
    elif [[ "$scenario" == *extra ]]; then
      grep -Fq "scenario did not render exactly the fixed safe refusal" "$output_file"
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

expect_reset_success_contract_is_required() {
  if run_smoke reset-contract-missing; then
    echo "smoke unexpectedly passed without the reset success marker" >&2
    exit 1
  fi
  grep -Fq "reset did not render the successful model-memory reset marker" "$output_file"
}

expect_happy_path_and_request_contract
expect_semantic_failure_is_closed
expect_html_entities_are_normalized
expect_reset_marker_failure_is_closed
expect_reset_success_contract_is_required
expect_secure_temporary_artifact_contract

echo "reference deployed smoke regression tests passed"
