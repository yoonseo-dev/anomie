// Claude API 크레딧 잔액 장부 보기·맞추기. 장부: server/logs/credit.jsonl (src/services/creditService.js)
// 사용: npm run credit                        잔액, 날짜별 사용액, 최근 사용 내역
//       npm run credit -- --set 4.70          Console에서 본 잔액으로 맞춘다
//       npm run credit -- --add 10            충전한 금액을 더한다
//       npm run credit -- --last 30           최근 사용 내역 개수 (기본 15)
const { readLedger, balanceOf, setBalance, addCredit, ledgerPath } = require('../src/services/creditService');
const { KRW_PER_USD } = require('../src/eval/pricing');

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i > -1 ? process.argv[i + 1] : undefined;
}

const usd = (n, d = 4) => (n == null ? '-' : `$${n.toFixed(d)}`);
const krw = (n) => (n == null ? '' : ` (약 ${Math.round(n * KRW_PER_USD).toLocaleString()}원)`);
// 기록은 UTC로 남기고, 보여 줄 때는 한국 시간으로 바꾼다
const kst = (iso) => new Date(new Date(iso).getTime() + 9 * 3600 * 1000).toISOString();

function amountArg(name) {
  const raw = arg(name);
  if (raw === undefined) return undefined;
  const n = Number(raw);
  if (!Number.isFinite(n) || n < 0) {
    console.error(`--${name} 뒤에는 0 이상의 달러 금액을 넣어 주세요 (예: --${name} 4.70)`);
    process.exit(1);
  }
  return n;
}

async function main() {
  const set = amountArg('set');
  const add = amountArg('add');
  const note = arg('note');
  if (set !== undefined) {
    const e = await setBalance(set, note);
    console.log(`잔액을 ${usd(e.balanceUsd, 2)}로 맞췄습니다` + (e.driftUsd != null ? ` (장부 추정과 차이 ${usd(e.driftUsd)})` : ''));
  }
  if (add !== undefined) {
    const e = await addCredit(add, note);
    console.log(`${usd(e.usd, 2)} 충전 → 잔액 ${usd(e.balanceUsd)}`);
  }

  const entries = await readLedger();
  const balance = balanceOf(entries);
  if (balance == null) {
    console.log(`기준 잔액이 없습니다. Console에서 본 잔액을 넣어 주세요: npm run credit -- --set 4.70`);
    return;
  }

  const lastSet = entries.findLastIndex((e) => e.type === 'set');
  const uses = entries.filter((e) => e.type === 'use');
  const since = entries.slice(lastSet).filter((e) => e.type === 'use');
  const spentSince = since.reduce((a, e) => a + (e.usd ?? 0), 0);
  const unpriced = uses.filter((e) => e.usd == null).length;

  console.log(`\n# Claude 크레딧 잔액 (추정)\n`);
  console.log(`- 현재 잔액: ${usd(balance)}${krw(balance)}`);
  console.log(
    `- 마지막으로 맞춘 때: ${kst(entries[lastSet].at).slice(0, 16).replace('T', ' ')} ${usd(entries[lastSet].balanceUsd, 2)}` +
      ` → 그 뒤 ${since.length}회 호출, ${usd(spentSince)} 사용`
  );
  if (unpriced) console.log(`- 단가표에 없는 모델 호출 ${unpriced}회는 차감하지 못했습니다 (src/eval/pricing.js에 추가)`);
  console.log(`- 이 서버 밖에서 같은 키로 쓴 비용은 빠져 있습니다. 가끔 Console 잔액으로 --set 해 주세요`);

  const byDay = new Map();
  for (const e of uses) {
    const day = kst(e.at).slice(0, 10);
    const d = byDay.get(day) ?? { count: 0, usd: 0, byWhat: new Map() };
    d.count++;
    d.usd += e.usd ?? 0;
    d.byWhat.set(e.what, (d.byWhat.get(e.what) ?? 0) + (e.usd ?? 0));
    byDay.set(day, d);
  }
  if (byDay.size) {
    console.log(`\n## 날짜별 사용액`);
    for (const [day, d] of [...byDay].reverse()) {
      const parts = [...d.byWhat].map(([w, v]) => `${w} ${usd(v)}`).join(', ');
      console.log(`- ${day} | ${d.count}회 | ${usd(d.usd)}${krw(d.usd)} | ${parts}`);
    }
  }

  const last = Number(arg('last') ?? 15);
  const recent = entries.slice(-last).reverse();
  console.log(`\n## 최근 ${recent.length}건`);
  for (const e of recent) {
    const at = kst(e.at).slice(5, 16).replace('T', ' ');
    if (e.type === 'use') console.log(`- ${at} | ${e.what} (${e.model}) | -${usd(e.usd)} | 잔액 ${usd(e.balanceUsd)}`);
    else
      console.log(
        `- ${at} | ${e.type === 'set' ? '잔액 맞춤' : '충전'}${e.note ? ` (${e.note})` : ''} | ` +
          `${e.type === 'add' ? '+' : ''}${usd(e.usd, 2)} | 잔액 ${usd(e.balanceUsd)}`
      );
  }
  console.log(`\n장부 파일: ${ledgerPath()}`);
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
