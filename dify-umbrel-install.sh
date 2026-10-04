#!/bin/bash
# Dify + Umbrel 대시보드 아이콘 설치 스크립트
#
# 1) Dify 를 docker compose 로 설치 (~/dify, 포트 8080/8443)
# 2) Dify 바로가기 앱이 든 Umbrel 커뮤니티 앱스토어 생성 (~/umbrel-dify-store)
# 3) 앱스토어를 GitHub 에 올리지 않았다면, 로컬(127.0.0.1)에서만 열리는 git 서버 실행
#
# 사용법:
#   bash dify-umbrel-install.sh
#
# 환경변수로 바꿀 수 있는 값:
#   DIFY_VERSION=1.17.1   설치할 Dify 버전 (git 태그)
#   DIFY_PORT=8080        Dify HTTP 포트 (Umbrel 이 80 을 쓰므로 80 금지)
#   DIFY_SSL_PORT=8443    Dify HTTPS 포트
#   STORE_ID=jennis       앱스토어 id (앱 id 는 <STORE_ID>-dify)
#   STORE_NAME="Jennis Apps"
#   SHORTCUT_PORT=5406    Umbrel 대시보드에서 여는 포트
#   STORE_URL=https://github.com/soundbook-creato/umbrel-dify-store
#                         GitHub 앱스토어를 쓸 때 지정하면 2·3단계(로컬 앱스토어)를 건너뜀
set -euo pipefail

DIFY_VERSION="${DIFY_VERSION:-1.17.1}"
DIFY_PORT="${DIFY_PORT:-8080}"
DIFY_SSL_PORT="${DIFY_SSL_PORT:-8443}"
STORE_ID="${STORE_ID:-jennis}"
STORE_NAME="${STORE_NAME:-Jennis Apps}"
SHORTCUT_PORT="${SHORTCUT_PORT:-5406}"
STORE_SERVER_PORT=18999

DIFY_DIR="$HOME/dify"
STORE_DIR="$HOME/umbrel-dify-store"
SERVER_PY="$HOME/umbrel-dify-store-server.py"
APP_ID="${STORE_ID}-dify"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m오류: %s\033[0m\n' "$*" >&2; exit 1; }

# docker 를 바로 쓸 수 있으면 그대로, 아니면 sudo
if docker ps >/dev/null 2>&1; then DOCKER=(docker); else DOCKER=(sudo docker); fi

step "사전 확인"
command -v git >/dev/null || die "git 이 없습니다"
command -v python3 >/dev/null || die "python3 가 없습니다"
"${DOCKER[@]}" compose version >/dev/null || die "docker compose 를 실행할 수 없습니다"
for p in "$DIFY_PORT" "$DIFY_SSL_PORT" "$SHORTCUT_PORT"; do
  if ss -ltn | awk '{print $4}' | grep -qE "[:.]${p}\$" && ! [[ -d "$DIFY_DIR" ]]; then
    die "포트 $p 가 이미 사용 중입니다. 환경변수로 다른 포트를 지정하세요"
  fi
done

# Umbrel 앱 네트워크(umbrel_main_network) 게이트웨이 = 컨테이너에서 본 호스트 주소
GATEWAY_IP="$(ip -4 -o addr | awk '{print $4}' | grep -m1 '^10\.21\.' | cut -d/ -f1 || true)"
[[ -n "$GATEWAY_IP" ]] || die "Umbrel 네트워크(10.21.x.x)를 찾지 못했습니다. umbrelOS 가 실행 중인지 확인하세요"
echo "Umbrel 게이트웨이: $GATEWAY_IP"

step "1/3 Dify $DIFY_VERSION 설치 ($DIFY_DIR)"
if [[ -f "$DIFY_DIR/docker-compose.yaml" ]]; then
  echo "이미 $DIFY_DIR 가 있어 내려받기는 건너뜁니다"
else
  tmp="$(mktemp -d)"
  git clone --depth 1 --branch "$DIFY_VERSION" https://github.com/langgenius/dify.git "$tmp/dify"
  cp -r "$tmp/dify/docker" "$DIFY_DIR"
  rm -rf "$tmp"
fi
cd "$DIFY_DIR"
[[ -f .env ]] || cp .env.example .env
sed -i "s/^EXPOSE_NGINX_PORT=.*/EXPOSE_NGINX_PORT=${DIFY_PORT}/" .env
sed -i "s/^EXPOSE_NGINX_SSL_PORT=.*/EXPOSE_NGINX_SSL_PORT=${DIFY_SSL_PORT}/" .env
"${DOCKER[@]}" compose up -d

echo -n "Dify 응답 대기"
for _ in $(seq 1 60); do
  if curl -s -o /dev/null -m 3 "http://127.0.0.1:${DIFY_PORT}/"; then echo " OK"; break; fi
  echo -n "."; sleep 5
done

if [[ -n "${STORE_URL:-}" ]]; then
  step "GitHub 앱스토어 사용: $STORE_URL"
  git ls-remote "$STORE_URL" >/dev/null || die "앱스토어 저장소에 접근할 수 없습니다: $STORE_URL"
  [[ "$GATEWAY_IP" == "10.21.0.1" ]] || echo "주의: 게이트웨이가 $GATEWAY_IP 입니다. GitHub 앱의 10.21.0.1 을 이 값으로 바꿔야 합니다"
  [[ "$DIFY_PORT" == "8080" ]] || echo "주의: GitHub 앱은 Dify 포트 8080 기준입니다"
else
step "2/3 Umbrel 앱스토어 생성 ($STORE_DIR)"
mkdir -p "$STORE_DIR/$APP_ID"
cat > "$STORE_DIR/umbrel-app-store.yml" <<EOF
id: ${STORE_ID}
name: ${STORE_NAME}
EOF
cat > "$STORE_DIR/$APP_ID/umbrel-app.yml" <<EOF
manifestVersion: 1
id: ${APP_ID}
category: ai
name: Dify
version: "1.0.1"
tagline: LLM 앱 개발 플랫폼
icon: https://avatars.githubusercontent.com/u/127165244
description: >-
  ~/dify 에서 docker compose로 실행 중인 Dify(포트 ${DIFY_PORT})를 Umbrel 대시보드에서 열 수 있게 해주는 바로가기 앱입니다.
  Dify 본체는 ~/dify 의 docker compose가 관리합니다.
developer: LangGenius
website: https://dify.ai
repo: https://github.com/langgenius/dify
support: https://github.com/langgenius/dify/issues
port: ${SHORTCUT_PORT}
gallery: []
path: ""
defaultUsername: ""
defaultPassword: ""
dependencies: []
submitter: ${STORE_ID}
EOF
cat > "$STORE_DIR/$APP_ID/docker-compose.yml" <<EOF
version: "3.7"

services:
  app_proxy:
    environment:
      APP_HOST: ${APP_ID}_proxy_1
      APP_PORT: 8080
      PROXY_AUTH_ADD: "false"

  proxy:
    # Forwards to Dify's nginx, published on the host at :${DIFY_PORT} (umbrel_main_network gateway)
    image: alpine/socat:1.8.1.3
    command: TCP-LISTEN:8080,fork,reuseaddr TCP:${GATEWAY_IP}:${DIFY_PORT}
    restart: on-failure
    container_name: ${APP_ID}_proxy_1
EOF
cd "$STORE_DIR"
[[ -d .git ]] || git init -q -b master
git add -A
git -c user.name="$STORE_ID" -c user.email="${STORE_ID}@localhost" commit -qm "Dify shortcut app" || echo "(변경 없음)"
touch .git/git-daemon-export-ok

step "3/3 로컬 앱스토어 서버 실행 (127.0.0.1:${STORE_SERVER_PORT})"
cat > "$SERVER_PY" <<EOF
# Minimal smart-HTTP git server (localhost only) so umbreld can clone ~/umbrel-dify-store
import os, subprocess
from wsgiref.simple_server import make_server

ROOT = os.path.expanduser('~')

def app(environ, start_response):
    env = {
        'GIT_PROJECT_ROOT': ROOT,
        'GIT_HTTP_EXPORT_ALL': '1',
        'REQUEST_METHOD': environ['REQUEST_METHOD'],
        'PATH_INFO': environ.get('PATH_INFO', ''),
        'QUERY_STRING': environ.get('QUERY_STRING', ''),
        'CONTENT_TYPE': environ.get('CONTENT_TYPE', ''),
        'CONTENT_LENGTH': environ.get('CONTENT_LENGTH', ''),
        'HTTP_GIT_PROTOCOL': environ.get('HTTP_GIT_PROTOCOL', ''),
        'REMOTE_ADDR': environ.get('REMOTE_ADDR', ''),
        'PATH': os.environ['PATH'],
    }
    length = int(environ.get('CONTENT_LENGTH') or 0)
    body = environ['wsgi.input'].read(length) if length else b''
    out = subprocess.run(['git', 'http-backend'], input=body, env=env, capture_output=True).stdout
    head, _, payload = out.partition(b'\r\n\r\n')
    status, headers = '200 OK', []
    for line in head.decode().split('\r\n'):
        k, _, v = line.partition(':')
        if k.lower() == 'status':
            status = v.strip()
        elif k:
            headers.append((k, v.strip()))
    start_response(status, headers)
    return [payload]

make_server('127.0.0.1', ${STORE_SERVER_PORT}, app).serve_forever()
EOF
if ! pgrep -f umbrel-dify-store-server.py >/dev/null; then
  nohup python3 "$SERVER_PY" > "$HOME/umbrel-dify-store-server.log" 2>&1 &
  sleep 1
fi
git ls-remote "http://127.0.0.1:${STORE_SERVER_PORT}/umbrel-dify-store" >/dev/null || die "로컬 앱스토어 서버 확인 실패"
STORE_LOCAL=1

STORE_URL="http://127.0.0.1:${STORE_SERVER_PORT}/umbrel-dify-store"
fi
cat <<EOF

$(printf '\033[1;32m')설치 준비 완료!$(printf '\033[0m')

Umbrel 웹에서 마무리하세요:
  1. App Store → 오른쪽 위 ⋯ → Community App Stores
  2. 다음 주소 추가:  ${STORE_URL}
  3. "${STORE_NAME}" → Dify → Install
  4. 대시보드의 Dify 아이콘 → 관리자 계정 생성 → 프로필 설정에서 언어를 한국어로

Dify 직접 접속:  http://<서버IP>:${DIFY_PORT}

EOF
if [[ -n "${STORE_LOCAL:-}" ]]; then cat <<EOF
참고: 로컬 앱스토어 서버는 재부팅하면 꺼집니다. 설치된 Dify 앱은 계속 동작하며
      Umbrel 로그에 스토어 갱신 실패만 남습니다. 서버 없이 쓰려면 ${STORE_DIR} 를
      GitHub 공개 저장소로 올리고 그 주소를 대신 등록하세요.
EOF
fi
