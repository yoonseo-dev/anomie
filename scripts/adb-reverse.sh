#!/usr/bin/env bash
# 안드로이드 실기기(무선 디버깅)의 localhost:PORT를 PC 서버로 잇는다.
# 무선 디버깅이 다시 연결되면 포트가 바뀌고 예전 포워딩이 사라지므로, 그때마다 실행한다.
#
#   scripts/adb-reverse.sh          # 3000번
#   scripts/adb-reverse.sh 3100     # 다른 포트
#
# 같은 폰이 "IP:포트"와 "adb-...-tls-connect" 두 줄로 잡히면 한 번만 건다 (IP:포트 쪽 우선).
set -euo pipefail

PORT="${1:-3000}"

if ! command -v adb >/dev/null 2>&1; then
  echo "adb를 찾을 수 없습니다. Android SDK의 platform-tools를 PATH에 추가하세요." >&2
  exit 1
fi

mapfile -t devices < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
if [ "${#devices[@]}" -eq 0 ]; then
  echo "연결된 기기가 없습니다. 휴대폰의 무선 디버깅 화면에서 IP:포트를 확인해 adb connect 하세요." >&2
  exit 1
fi

# IP:포트 연결을 앞에 둔다 (mDNS 이름 연결보다 안정적)
mapfile -t devices < <(printf '%s\n' "${devices[@]}" | sort -t: -k1,1 -r | awk '/:[0-9]+$/ {print; next} {rest[++n]=$0} END {for (i=1;i<=n;i++) print rest[i]}')

# 끊긴 채 남은 포워딩이 목록에만 보이는 경우가 있어 먼저 모두 지운다.
# (같은 폰의 연결끼리는 포워딩 목록을 같이 쓰므로, 거는 도중에 지우면 방금 건 것까지 지워진다)
for d in "${devices[@]}"; do
  adb -s "$d" reverse --remove-all >/dev/null 2>&1 || true
done

declare -A done_serials=()
for d in "${devices[@]}"; do
  serial=$(adb -s "$d" shell getprop ro.serialno 2>/dev/null | tr -d '\r')
  if [ -n "$serial" ] && [ -n "${done_serials[$serial]:-}" ]; then
    echo "· $d: 같은 기기($serial)라 건너뜀"
    continue
  fi
  done_serials[$serial]=1

  adb -s "$d" reverse "tcp:$PORT" "tcp:$PORT" >/dev/null
  # 휴대폰 안에서 실제로 서버 응답이 오는지 확인한다 (응답을 받을 때까지 연결을 열어 둔다)
  status=$(adb -s "$d" shell "(printf 'GET / HTTP/1.0\r\nHost: localhost\r\n\r\n'; sleep 2) | toybox timeout 5 toybox nc 127.0.0.1 $PORT | head -1" 2>/dev/null | tr -d '\r')
  if [ -n "$status" ]; then
    echo "✓ $d: localhost:$PORT → PC:$PORT 연결됨 ($status)"
  else
    echo "✗ $d: 포워딩은 걸었지만 응답이 없습니다. PC에서 서버(포트 $PORT)가 켜져 있는지 확인하세요." >&2
  fi
done
