require('dotenv/config');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

// Prisma 7은 WASM 기반으로 전환되어 내장 DB 드라이버가 없음 → pg 어댑터 필요
const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });

// Prisma 클라이언트 싱글톤 - DB 연결을 앱 전체에서 공유
const prisma = new PrismaClient({ adapter });

module.exports = prisma;
