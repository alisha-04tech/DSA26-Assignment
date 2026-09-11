#!/usr/bin/env bash
# =============================================================================
# smoke-test.sh - exercises every endpoint and CHECKS the status codes.
# Start the service first:  bal run library_service
# Then:                     bash smoke-test.sh
# =============================================================================
set -u
HOST="${HOST:-http://localhost:9090/library}"
PASS=0; FAIL=0

check() {                      # check <expected> <method> <path> [body]
  local want="$1" method="$2" path="$3" body="${4:-}"
  local got
  if [ -n "$body" ]; then
    got=$(curl -s -o /tmp/resp.json -w '%{http_code}' -X "$method" "$HOST$path" \
          -H 'Content-Type: application/json' -d "$body")
  else
    got=$(curl -s -o /tmp/resp.json -w '%{http_code}' -X "$method" "$HOST$path")
  fi
  if [ "$got" = "$want" ]; then
    PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %-6s %-56s %s\n' "$method" "$path" "$got"
  else
    FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %-6s %-56s got %s want %s\n' "$method" "$path" "$got" "$want"
    sed 's/^/         /' /tmp/resp.json 2>/dev/null | head -2
  fi
}

echo "Testing $HOST"
echo "--- reads -------------------------------------------------------------"
check 200 GET  "/health"
check 200 GET  "/assets"
check 200 GET  "/assets?institution=University%20of%20Namibia"
check 200 GET  "/assets/NUST-LIB-3DP-001"
check 200 GET  "/assets/NUST-LIB-3DP-001/schedules"
check 200 GET  "/overdue"
check 200 GET  "/overdue?institution=Namibia%20University%20of%20Science%20and%20Technology"
check 200 GET  "/institutions"
check 200 GET  "/institutions/NUST/assets"

echo "--- error handling ----------------------------------------------------"
check 404 GET  "/assets/DOES-NOT-EXIST"
check 404 GET  "/institutions/ZZZ/assets"
check 404 PUT  "/assets/DOES-NOT-EXIST" '{"name":"x"}'
check 404 DELETE "/assets/DOES-NOT-EXIST"

echo "--- create / update / delete ------------------------------------------"
NEW='{"assetTag":"TEST-001","name":"Test Rig","institution":"Namibia University of Science and Technology","site":"Main Campus - Library","dateAcquired":"2025-01-01"}'
check 201 POST "/assets" "$NEW"
check 409 POST "/assets" "$NEW"
check 200 PUT  "/assets/TEST-001" '{"description":"updated by smoke test"}'

echo "--- schedules ---------------------------------------------------------"
check 201 POST "/assets/TEST-001/schedules" '{"scheduleId":"S-1","type":"MAINTENANCE","dueDate":"2026-12-01","description":"test"}'
check 409 POST "/assets/TEST-001/schedules" '{"scheduleId":"S-1","type":"MAINTENANCE","dueDate":"2026-12-01","description":"dup"}'
check 400 POST "/assets/TEST-001/schedules" '{"scheduleId":"S-2","type":"MAINTENANCE","dueDate":"01-12-2026","description":"bad date"}'
check 200 DELETE "/assets/TEST-001/schedules/S-1"
check 404 DELETE "/assets/TEST-001/schedules/S-1"

echo "--- components --------------------------------------------------------"
check 201 POST "/assets/TEST-001/components" '{"compId":"C-1","name":"Widget","description":"d"}'
check 409 POST "/assets/TEST-001/components" '{"compId":"C-1","name":"Dup","description":"d"}'
check 200 DELETE "/assets/TEST-001/components/C-1"

echo "--- work orders -------------------------------------------------------"
check 201 POST "/assets/TEST-001/workorders" '{"orderId":"W-1","status":"OPEN","description":"broken","tasks":[]}'
check 201 POST "/assets/TEST-001/workorders/W-1/tasks" '{"taskId":"T-1","description":"fix it"}'
check 200 PUT  "/assets/TEST-001/workorders/W-1" '{"status":"CLOSED"}'
check 200 DELETE "/assets/TEST-001/workorders/W-1/tasks/T-1"
check 404 PUT  "/assets/TEST-001/workorders/NOPE" '{"status":"CLOSED"}'

echo "--- loan lifecycle ----------------------------------------------------"
check 200 PUT  "/assets/TEST-001" '{"status":"AVAILABLE"}'
check 200 POST "/assets/TEST-001/loan" '{"borrowerId":"212091050","dueDate":"2026-09-30","type":"LOAN"}'
check 409 POST "/assets/TEST-001/loan" '{"borrowerId":"999999","dueDate":"2026-09-30","type":"LOAN"}'
check 200 POST "/assets/TEST-001/checkin"
check 409 POST "/assets/TEST-001/checkin"
check 400 POST "/assets/TEST-001/loan" '{"borrowerId":"212091050","dueDate":"30-09-2026","type":"LOAN"}'
check 404 POST "/assets/GHOST/loan" '{"borrowerId":"212091050","dueDate":"2026-09-30","type":"LOAN"}'

echo "--- institutions ------------------------------------------------------"
check 201 POST "/institutions" '{"code":"IUM","name":"International University of Management","sites":["Dorado Campus"]}'
check 409 POST "/institutions" '{"code":"IUM","name":"Dup","sites":[]}'
check 200 PUT  "/institutions/IUM" '{"sites":["Dorado Campus","Walvis Bay Campus"]}'
check 200 DELETE "/institutions/IUM"
check 404 DELETE "/institutions/IUM"
check 409 DELETE "/institutions/NUST"

echo "--- cleanup -----------------------------------------------------------"
check 200 DELETE "/assets/TEST-001"
check 404 DELETE "/assets/TEST-001"

echo
echo "======================================================================="
printf '  PASSED: %d    FAILED: %d\n' "$PASS" "$FAIL"
echo "======================================================================="
[ "$FAIL" -eq 0 ]
