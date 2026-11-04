#!/usr/bin/env bash
# 안드로이드 실기기(USB·무선 디버깅)로 앱을 띄운다. 포워딩을 먼저 걸고 서버 주소도 넣어 준다.
#
#   scripts/run-android.sh                 # 서버 3000번
#   PORT=3100 scripts/run-android.sh       # 다른 포트의 서버
#   scripts/run-android.sh --release       # 뒤에 붙인 인자는 flutter run에 그대로 넘긴다
#
# 기기를 고르는 순서: USB 연결 → 무선(IP:포트) 연결. 같은 폰이 두 방식으로 잡혀 있어도 하나만 쓴다.
set -euo pipefail

PORT="${PORT:-3000}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1) 포워딩 (기기가 없으면 여기서 안내하고 멈춘다)
bash "$ROOT/scripts/adb-reverse.sh" "$PORT"

# 2) 실행할 기기: USB(이름에 ':'가 없는 것)를 먼저, 없으면 무선 IP:포트
mapfile -t devices < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
device=""
for d in "${devices[@]}"; do
  case "$d" in *:* | adb-*) ;; *) device="$d"; break ;; esac
done
if [ -z "$device" ]; then
  for d in "${devices[@]}"; do
    case "$d" in *:*) device="$d"; break ;; esac
  done
fi
device="${device:-${devices[0]}}"

echo "→ $device 에서 실행 (API_BASE_URL=http://localhost:$PORT)"
cd "$ROOT/client"
exec flutter run -d "$device" --dart-define="API_BASE_URL=http://localhost:$PORT" "$@"
