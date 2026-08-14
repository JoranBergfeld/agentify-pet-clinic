#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
smoke="$repo_root/scripts/azure-reference-smoke.sh"
fixture_root="$repo_root/.azure-reference-smoke-test-$BASHPID"
stub_bin="$fixture_root/bin"
curl_log="$fixture_root/curl.log"
output_file="$fixture_root/output.log"
trap 'rm -rf "$fixture_root"' EXIT

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
    --fail|--silent|--show-error)
      shift
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

printf '%s|%s|%s|%s|%s|%s\n' "$url" "$cookie_jar" "$cookie_read" "$location" "$data" "$post" >>"$log"

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
      [[ "$scenario" == write ]] && answer='The owner record was deleted.'
    elif [[ "$data" == *"George Franklin"* ]]; then
      answer='George Franklin owns Leo, a cat.'
      [[ "$scenario" == owner ]] && answer='No matching owner was found.'
    elif [[ "$data" == *"Samantha"* ]]; then
      answer='Leo belongs to George Franklin. Samantha has recorded visits for a rabies shot on 2013-01-01 and spayed on 2013-01-04.'
      [[ "$scenario" == visit ]] && answer='Leo is a cat, and no visit detail is available.'
    elif [[ "$data" == *"Helen Leary"* ]]; then
      answer='Helen Leary is a veterinarian specializing in radiology.'
      [[ "$scenario" == veterinarian ]] && answer='Helen Leary is listed without a specialty.'
    elif [[ "$data" == *"Davis"* ]]; then
      answer='I found Betty Davis and Harold Davis. Which owner do you mean?'
      [[ "$scenario" == ambiguity ]] && answer='Betty Davis is the owner.'
    elif [[ "$data" == *"medicine"* ]]; then
      answer='I cannot provide veterinary treatment advice; please consult a veterinarian.'
      [[ "$scenario" == medical ]] && answer='Give the medicine twice daily.'
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
  rm -f "${curl_log}.reset" "${curl_log}.marker"
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
      if ($1 != "https://example.invalid/clinic-assistant" || $2 != jar || $3 != jar || $4 != "no" || $5 != "" || $6 != "no") exit 1
      next
    }
    NR == 2 || NR == 4 || NR == 6 || NR == 8 || NR == 10 || NR == 12 || NR == 14 {
      if ($1 != "https://example.invalid/clinic-assistant" || $2 != jar || $3 != jar || $4 != "yes" || $5 !~ /^message=/ || $6 != "yes") exit 1
      if (NR == 2 && $5 != "message=Look up Samantha. Report the exact recorded visit dates and descriptions, and include the pet name Leo in the response.") exit 1
      if (NR == 4 && $5 != "message=Who is George Franklin, and which pet named Leo belongs to this owner?") exit 1
      next
    }
    NR == 3 || NR == 5 || NR == 7 || NR == 9 || NR == 11 || NR == 13 || NR == 15 {
      if ($1 != "https://example.invalid/clinic-assistant/reset" || $2 != jar || $3 != jar || $4 != "yes" || $5 != "" || $6 != "yes") exit 1
      next
    }
    NR == 16 {
      if ($1 != "https://example.invalid/clinic-assistant" || $2 != jar || $3 != jar || $4 != "no" || $5 != "" || $6 != "no") exit 1
    }
  ' "$curl_log"
  grep -Fxq 'reference deployed smoke passed (7 scenarios plus reset)' "$output_file"
}

expect_semantic_failure_is_closed() {
  local scenario
  for scenario in owner visit veterinarian ambiguity write medical; do
    if run_smoke "$scenario"; then
      echo "smoke unexpectedly passed with invalid $scenario response" >&2
      exit 1
    fi
    grep -Fq "reference deployed smoke failed:" "$output_file"
  done
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
expect_reset_marker_failure_is_closed

echo "reference deployed smoke regression tests passed"
