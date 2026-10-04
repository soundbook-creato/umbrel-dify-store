# umbrel-dify-store

docker compose로 따로 실행 중인 [Dify](https://github.com/langgenius/dify)를 Umbrel 대시보드에 아이콘으로 띄우는 커뮤니티 앱스토어입니다.

앱(`jennis-dify`)은 Dify를 새로 설치하지 않습니다. 작은 socat 컨테이너가 호스트의 Dify(`10.21.0.1:8080`)로 연결을 넘겨주는 바로가기입니다.

## 새 Umbrel 서버에 설치

```bash
curl -fsSLO https://raw.githubusercontent.com/soundbook-creato/umbrel-dify-store/main/dify-umbrel-install.sh
STORE_URL=https://github.com/soundbook-creato/umbrel-dify-store bash dify-umbrel-install.sh
```

1. 스크립트가 Dify를 `~/dify`에 설치하고 포트를 8080/8443으로 맞춥니다.
2. Umbrel 웹 → App Store → ⋯ → Community App Stores → `https://github.com/soundbook-creato/umbrel-dify-store` 추가
3. **Jennis Apps → Dify → Install**
