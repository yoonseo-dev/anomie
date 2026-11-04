# Anomie API 서버 (배포용). 서버(EC2) 위에서 빌드하므로 x86·Arm 어느 쪽이든 그 기계에 맞게 만들어진다.
FROM node:22-slim

WORKDIR /app

# 의존성 먼저 (코드만 바뀌면 이 층은 다시 받지 않는다). prisma CLI도 dependencies라 migrate deploy를 쓸 수 있다.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Prisma 7은 설치 때 클라이언트를 자동으로 만들지 않는다
COPY prisma ./prisma
COPY prisma.config.ts ./
RUN npx prisma generate

COPY index.js ./
COPY src ./src
COPY scripts ./scripts

# 비용·채점 기록(logs/)은 볼륨으로 붙인다. node 사용자(uid 1000)가 쓸 수 있게 미리 만든다
RUN mkdir -p logs && chown -R node:node /app
USER node

ENV NODE_ENV=production
EXPOSE 3000

# 시작할 때마다 밀린 마이그레이션을 적용한다 (서버 한 대라 동시에 돌 일이 없다)
CMD ["sh", "-c", "npx prisma migrate deploy && node index.js"]
