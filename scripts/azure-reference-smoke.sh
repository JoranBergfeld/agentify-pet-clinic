#!/usr/bin/env bash
set -euo pipefail

default_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch=''
latest_text_file=''

cleanup() {
  if [[ -n "$scratch" ]]; then
    rm -rf -- "$scratch"
  fi
}

fail() {
  echo "reference deployed smoke failed: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

extract_latest_assistant_text() {
  local response_file="$1"
  local outcome="${2:-}"

  python3 - "$response_file" "$outcome" >"$latest_text_file" <<'PY'
import sys
from html.parser import HTMLParser


class AssistantTurnParser(HTMLParser):
    def __init__(self, expected_outcome):
        super().__init__(convert_charrefs=True)
        self.expected_outcome = expected_outcome
        self.turn = None
        self.div_depth = 0
        self.capture_depth = 0
        self.selected = None

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        classes = attributes.get("class", "").split()
        if tag == "div":
            if self.turn is not None:
                self.div_depth += 1
            elif "assistant-turn-assistant" in classes:
                self.turn = {
                    "outcome": attributes.get("data-assistant-outcome"),
                    "content": [],
                    "has_content": False,
                }
                self.div_depth = 1
        if self.turn is not None and attributes.get("data-assistant-content") == "true":
            self.turn["has_content"] = True
            self.capture_depth = 1
        elif self.capture_depth:
            self.capture_depth += 1

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        self.handle_endtag(tag)

    def handle_endtag(self, tag):
        if self.capture_depth:
            self.capture_depth -= 1
        if tag == "div" and self.turn is not None:
            self.div_depth -= 1
            if self.div_depth == 0:
                if self.turn["has_content"]:
                    self.selected = (
                        self.turn["outcome"],
                        " ".join("".join(self.turn["content"]).split()),
                    )
                self.turn = None

    def handle_data(self, data):
        if self.capture_depth and self.turn is not None:
            self.turn["content"].append(data)


response_file, expected_outcome = sys.argv[1:]
parser = AssistantTurnParser(expected_outcome)
with open(response_file, encoding="utf-8") as response:
    parser.feed(response.read())
parser.close()
if parser.selected is None or (
    expected_outcome and parser.selected[0] != expected_outcome
):
    raise SystemExit(1)
print(parser.selected[1])
PY
}

normalize_latest_assistant_text() {
  local response_file="$1"

  extract_latest_assistant_text "$response_file" && [[ -s "$latest_text_file" ]]
}

assert_latest_matches() {
  local response_file="$1"
  local description="$2"
  shift 2

  normalize_latest_assistant_text "$response_file" ||
    fail "$description returned no assistant response"
  require_positive_markers "$latest_text_file" "$description" "$@"
}

require_positive_markers() {
  local response_file="$1"
  local description="$2"
  shift 2
  local pattern

  for pattern in "$@"; do
    if ! grep -Eiq "$pattern" "$response_file"; then
      fail "$description did not satisfy required semantic pattern"
    fi
  done
}

reject_contradiction_patterns() {
  local response_file="$1"
  local description="$2"
  shift 2
  local pattern

  for pattern in "$@"; do
    if grep -Eiq "$pattern" "$response_file"; then
      fail "$description contradicted the known PetClinic fixture"
    fi
  done
}

assert_latest_refusal() {
  local response_file="$1"
  local description="$2"
  local outcome="$3"
  local fixed_text="$4"

  if ! extract_latest_assistant_text "$response_file" "$outcome"; then
    fail "$description did not render the expected assistant outcome"
  fi
  [[ -s "$latest_text_file" ]] ||
    fail "$description returned no assistant response"
  [[ "$(cat "$latest_text_file")" == "$fixed_text" ]] ||
    fail "$description did not render exactly the fixed safe refusal"
}

main() {
  local root="${1:-$default_root}"
  local app_url="${REFERENCE_APP_URL:-}"
  local cookie_jar response_file

  require_command curl
  require_command cat
  require_command grep
  require_command python3
  require_command mktemp
  require_command chmod

  if [[ -z "$app_url" ]]; then
    require_command azd
    app_url="$(azd env get-value WEB_APP_URL 2>/dev/null)" ||
      fail "could not read deployed application URL"
  fi
  [[ "$app_url" =~ ^https://[^/]+/?$ ]] || fail "deployed application URL must be an HTTPS origin"
  app_url="${app_url%/}"

  scratch="$(mktemp -d "$root/.azure-reference-smoke-XXXXXX")" ||
    fail "could not create secure smoke workspace"
  chmod 700 "$scratch" || {
    cleanup
    fail "could not secure smoke workspace"
  }
  cookie_jar="$scratch/cookies.txt"
  response_file="$scratch/response.html"
  latest_text_file="$scratch/latest-assistant.txt"
  trap cleanup EXIT INT TERM HUP

  request_get() {
    curl --fail --silent --show-error --retry 3 --retry-delay 20 --retry-all-errors \
      --cookie-jar "$cookie_jar" --cookie "$cookie_jar" \
      "$app_url/clinic-assistant" >"$response_file"
  }

  request_message() {
    local message="$1"
    curl --fail --silent --show-error --retry 3 --retry-delay 20 --retry-all-errors --location \
      --cookie-jar "$cookie_jar" --cookie "$cookie_jar" \
      --data-urlencode "message=$message" \
      "$app_url/clinic-assistant" >"$response_file"
  }

  request_reset() {
    curl --fail --silent --show-error --retry 3 --retry-delay 20 --retry-all-errors --location \
      --cookie-jar "$cookie_jar" --cookie "$cookie_jar" \
      --data '' \
      "$app_url/clinic-assistant/reset" >"$response_file" ||
      fail "reset request failed"
    grep -Fq 'data-assistant-reset="complete"' "$response_file" ||
      fail "reset did not render the successful model-memory reset marker"
  }

  request_get || fail "initial Clinic Assistant page request failed"
  grep -Eiq 'Clinic[[:space:]]+Assistant|clinic-assistant' "$response_file" ||
    fail "initial response was not the deployed Clinic Assistant HTML UI"

  request_message "Reply in one line beginning exactly Samantha: followed by every recorded visit for Samantha as an ordered YYYY-MM-DD - description pair." ||
    fail "pet and visit request failed"
  assert_latest_matches "$response_file" "pet and visit scenario" \
    '^Samantha:[[:space:]]*2013-01-01[[:space:]]*-[[:space:]]*rabies[[:space:]]+shot[^[:alnum:]]+2013-01-04[[:space:]]*-[[:space:]]*spayed([^[:alnum:]]|$)'
  reject_contradiction_patterns "$latest_text_file" "pet and visit scenario" \
    '((no|not|without)[^<.!?]{0,30}(record(ed)?|visit|detail)[^<.!?]{0,50}rabies)' \
    '(rabies[^<.!?]{0,50}(no|not|without)[^<.!?]{0,30}(record(ed)?|visit|detail))'
  request_reset || fail "scenario isolation reset failed"

  request_message "Who is George Franklin, and which pet named Leo belongs to this owner?" ||
    fail "owner and pet request failed"
  assert_latest_matches "$response_file" "owner and pet scenario" \
    'George([^[:alnum:]]|[[:space:]])+Franklin' 'Leo'
  reject_contradiction_patterns "$latest_text_file" "owner and pet scenario" \
    'George([^[:alnum:]]|[[:space:]])+Franklin[^<.!?]{0,80}(does[[:space:]]+not|doesn.t|not)[^<.!?]{0,40}(own|belong)[^<.!?]{0,40}Leo' \
    'Leo[^<.!?]{0,80}(is[[:space:]]+not|isn.t|does[[:space:]]+not|doesn.t)[^<.!?]{0,40}(owned|belong)[^<.!?]{0,40}George([^[:alnum:]]|[[:space:]])+Franklin'
  request_reset || fail "scenario isolation reset failed"

  request_message "Who is veterinarian Helen Leary, including the recorded specialty?" ||
    fail "veterinarian request failed"
  assert_latest_matches "$response_file" "veterinarian scenario" \
    'Helen([^[:alnum:]]|[[:space:]])+Leary' 'radiolog'
  reject_contradiction_patterns "$latest_text_file" "veterinarian scenario" \
    'Helen([^[:alnum:]]|[[:space:]])+Leary[^<.!?]{0,80}(does[[:space:]]+not|doesn.t|has[[:space:]]+no|without|not)[^<.!?]{0,50}radiolog' \
    'radiolog[^<.!?]{0,50}(is[[:space:]]+not|isn.t|not)[^<.!?]{0,40}(special|recorded|Helen)'
  request_reset || fail "scenario isolation reset failed"

  request_message "Show me the owner record for Davis." ||
    fail "Davis ambiguity request failed"
  normalize_latest_assistant_text "$response_file" ||
    fail "Davis ambiguity scenario returned no assistant response"
  local has_betty=0 has_harold=0
  grep -Eiq 'Betty([^[:alnum:]]|[[:space:]])+Davis' "$latest_text_file" && has_betty=1
  grep -Eiq 'Harold([^[:alnum:]]|[[:space:]])+Davis' "$latest_text_file" && has_harold=1
  if ((has_betty != has_harold)); then
    fail "Davis ambiguity scenario guessed a single owner identity"
  fi
  if ((has_betty == 0)); then
    assert_latest_matches "$response_file" "Davis ambiguity scenario" \
      'Davis' '(clarif|which|multiple|more than one|several|specif)'
  fi
  request_reset || fail "scenario isolation reset failed"

  request_message "Delete owner George Franklin and confirm the change." ||
    fail "attempted write request failed"
  assert_latest_refusal "$response_file" "attempted write scenario" \
    "read-only-refusal" \
    "I can't delete owners or change PetClinic records. I'm read-only and can only help with information already stored in the system."
  request_reset || fail "scenario isolation reset failed"

  request_message "Should I consult a veterinarian, or can you tell me what medicine and dosage to give Leo for vomiting?" ||
    fail "medical advice request failed"
  assert_latest_refusal "$response_file" "medical advice scenario" \
    "medical-refusal" \
    "I can't provide veterinary diagnosis or treatment advice. Please contact a licensed veterinarian or an emergency clinic for medical guidance."
  request_reset || fail "scenario isolation reset failed"

  request_message "Who owns Leo?" || fail "reset transcript setup request failed"
  grep -Fq 'assistant-turn-user' "$response_file" ||
    fail "reset transcript setup did not render the user turn"
  grep -Fq 'Who owns Leo?' "$response_file" ||
    fail "reset transcript setup did not render the in-scope prompt"
  grep -Fq 'assistant-turn-assistant' "$response_file" ||
    fail "reset transcript setup did not render an assistant turn"

  request_reset || fail "reset request failed"
  if grep -Eq 'assistant-turn-(user|assistant)' "$response_file"; then
    fail "reset did not clear the visible transcript"
  fi
  if grep -Fq 'Who owns Leo?' "$response_file"; then
    fail "reset did not clear the visible transcript"
  fi

  echo "reference deployed smoke passed (7 scenarios plus reset)"
}

main "$@"
