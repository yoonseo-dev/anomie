# 배포 (EC2 한 대)

```
휴대폰 앱 ──https──▶ anomie-dev.duckdns.org (탄력적 IP)
                      EC2 (서울, Ubuntu 24.04)
                      ├─ caddy  : 80/443, HTTPS 인증서 자동 발급·갱신 → server:3000
                      ├─ server : Node API (server/Dockerfile, 시작할 때 migrate deploy)
                      └─ db     : PostgreSQL 17 (밖으로 열지 않음, 볼륨 pgdata)
```

파일: `docker-compose.prod.yml`, `server/Dockerfile`, `Caddyfile`, `.env.prod.example`, `scripts/backup-db.sh`

## 준비 (한 번)

- EC2: 서울 리전, Ubuntu 24.04, t4g.small 또는 t3.small(메모리 2GB), gp3 20GB
- 보안 그룹: 22는 **내 IP만**, 80·443은 전체. 3000·5432·5433은 열지 않는다
- 탄력적 IP를 인스턴스에 연결 (인스턴스를 지울 때 반드시 같이 반납)
- DuckDNS `anomie-dev`의 current ip = 탄력적 IP (`nslookup anomie-dev.duckdns.org`로 확인)

## 서버 설치 (한 번)

```bash
ssh -i <키.pem> ubuntu@<탄력적 IP>

sudo apt update && sudo apt upgrade -y
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
exit                                   # 다시 접속해야 docker를 sudo 없이 쓴다

git clone <저장소 주소> anomie && cd anomie
git checkout redesign-db-and-client    # 배포할 브랜치
```

메모리가 2GB면 이미지를 빌드할 때 빠듯할 수 있어 스왑을 만들어 둔다:

```bash
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## 비밀값 (한 번, 커밋하지 않는다)

```bash
cp -n .env.prod.example .env           # POSTGRES_PASSWORD=$(openssl rand -hex 24) 값을 넣는다
cp -n server/.env.example server/.env  # JWT_SECRET(openssl rand -hex 32), ANTHROPIC_API_KEY, GOOGLE_VISION_API_KEY
nano .env && nano server/.env
```

- `server/.env`의 `DATABASE_URL`은 compose가 `db` 주소로 덮어쓰므로 그대로 둬도 된다.
- `TRUST_PROXY=1`, `PORT=3000`도 compose가 넣는다.
- 채점 비용을 아끼려면 `server/.env`에 `ANALYSIS_JUDGE=off` 또는 `ANALYSIS_JUDGE_UNTIL=YYYY-MM-DD`.

## 띄우기 / 업데이트

```bash
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml logs -f server      # "서버가 포트 3000에서 실행 중입니다."
curl https://anomie-dev.duckdns.org/concepts                   # {"message":"인증 토큰이 없습니다."} 면 성공
```

코드를 바꾼 뒤: `git pull` → 같은 `up -d --build` (마이그레이션은 서버가 시작할 때 적용한다).

## 로그·기록 보기

```bash
C="docker compose -f docker-compose.prod.yml"
$C logs --tail 100 server                 # 서버 (분석·OCR·오류)
$C logs caddy | grep handled | tail -20   # 들어온 요청 (경로·상태 코드·걸린 시간)
$C exec server npm run eval:report        # 분석 비용·채점 요약 (기록은 server_logs 볼륨)
$C exec server npm run credit             # Claude 크레딧 잔액(추정)
```

앱에서 실패했는데 server 로그가 비어 있으면, caddy 로그에서 요청이 들어왔는지부터 본다.

인증서가 안 받아지면 `docker compose -f docker-compose.prod.yml logs caddy`를 본다.
대부분 DuckDNS가 다른 IP를 가리키거나 80·443이 막힌 경우다.

## 백업

```bash
bash scripts/backup-db.sh               # ~/backups/anomie-날짜.sql.gz, 14일치 보관
crontab -e                              # 매일 새벽 4시:
# 0 4 * * * cd ~/anomie && bash scripts/backup-db.sh >> ~/backups/backup.log 2>&1
```

서버가 사라지면 백업도 같이 사라진다. 가끔 PC로 받아 둔다:
`scp -i <키.pem> "ubuntu@<탄력적 IP>:~/backups/anomie-*.sql.gz" .`
(AWS 무료 플랜이 끝나 계정이 닫히기 전에 특히 꼭)

## 마무리 설정

- Google Cloud: Vision API 키 제한 → IP 주소 → 탄력적 IP
- Anthropic Console: 월 사용 한도
- AWS Budgets: 월 $10 초과 시 메일

## 앱 빌드

```bash
cd client
flutter build apk --release --dart-define=API_BASE_URL=https://anomie-dev.duckdns.org
```

배포 서버는 https라 `usesCleartextTraffic`(디버그 빌드 전용) 없이 접속한다.
