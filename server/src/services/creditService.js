const fs = require('fs/promises');
const path = require('path');
const { claudeCost } = require('../eval/pricing');

// Claude API 크레딧 잔액 장부. Anthropic API는 잔액을 알려 주지 않으므로
// Console에서 본 잔액을 기준으로 넣고(set), 충전하면 더하고(add), Claude를 부를 때마다 정가 기준 비용을 뺀다(use).
// 한 줄에 한 건씩 server/logs/credit.jsonl에 쌓고, 줄마다 그 시점의 잔액(balanceUsd)을 남긴다.
// 추정치다: 이 서버 밖에서 같은 키로 쓴 비용, 단가표에 없는 모델의 비용은 빠진다. 가끔 Console 잔액으로 다시 맞춘다.

const DEFAULT_LOG_DIR = path.join(__dirname, '../../logs');
const ledgerPath = () => path.join(process.env.CREDIT_LOG_DIR || DEFAULT_LOG_DIR, 'credit.jsonl');

// 테스트(node --test)에서는 실제 장부를 건드리지 않는다. 장부 테스트는 CREDIT_LOG_DIR로 임시 폴더를 준다.
const ledgerOn = () =>
  process.env.CREDIT_LOG !== 'off' && !(process.env.NODE_TEST_CONTEXT && !process.env.CREDIT_LOG_DIR);

const round = (n) => Number(n.toFixed(6));

async function readLedger() {
  try {
    const text = await fs.readFile(ledgerPath(), 'utf8');
    return text
      .split('\n')
      .filter(Boolean)
      .map((line) => JSON.parse(line));
  } catch (err) {
    if (err.code === 'ENOENT') return [];
    throw err;
  }
}

// 마지막 줄의 잔액. 기준 잔액을 아직 넣지 않았으면 null
const balanceOf = (entries) => (entries.length ? entries[entries.length - 1].balanceUsd : null);

// 같은 프로세스 안에서 동시에 기록하면 같은 잔액에서 빼게 되므로 한 줄씩 차례로 쓴다
let queue = Promise.resolve();
function append(makeEntry) {
  const run = queue.then(async () => {
    const entry = { at: new Date().toISOString(), ...makeEntry(balanceOf(await readLedger())) };
    await fs.mkdir(path.dirname(ledgerPath()), { recursive: true });
    await fs.appendFile(ledgerPath(), JSON.stringify(entry) + '\n');
    return entry;
  });
  queue = run.catch(() => {});
  return run;
}

// Console에서 본 잔액으로 맞춘다 (처음 시작할 때, 추정치가 어긋났을 때)
function setBalance(usd, note) {
  return append((prev) => ({
    type: 'set',
    usd: round(usd),
    balanceUsd: round(usd),
    ...(prev != null && { driftUsd: round(usd - prev) }), // 장부 추정과 실제의 차이
    ...(note && { note }),
  }));
}

// 충전한 금액을 더한다
function addCredit(usd, note) {
  return append((prev) => {
    if (prev == null) throw new Error('기준 잔액이 없습니다. 먼저 --set으로 현재 잔액을 넣어 주세요');
    return { type: 'add', usd: round(usd), balanceUsd: round(prev + usd), ...(note && { note }) };
  });
}

// Claude 호출 한 번의 비용을 뺀다. what: 어떤 호출인지 ("기사", "책 구절", "채점" 등)
// 단가를 모르는 모델이면 usd를 null로 남기고 잔액은 그대로 둔다 (비용을 지어내지 않는다)
function recordUsage({ usage, what }) {
  if (!ledgerOn()) return Promise.resolve(null);
  const cost = claudeCost(usage);
  return append((prev) => ({
    type: 'use',
    what,
    model: usage.model,
    usd: cost == null ? null : round(cost),
    balanceUsd: prev == null || cost == null ? prev : round(prev - cost),
  }));
}

// 응답을 기다리게 하지 않는다. 실패는 로그로만 남긴다.
function recordUsageInBackground(args) {
  recordUsage(args).catch((err) => console.error(`[잔액] 기록 실패: ${err.message}`));
}

module.exports = { readLedger, balanceOf, setBalance, addCredit, recordUsage, recordUsageInBackground, ledgerPath };
