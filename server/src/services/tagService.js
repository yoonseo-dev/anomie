const prisma = require('../prisma');
const httpError = require('../utils/httpError');

// Claude에 넘길 사용자의 기존 태그 목록 (오래된 것부터)
function findExistingTags(userId) {
  return prisma.tag.findMany({
    where: { userId },
    select: { id: true, name: true, description: true },
    orderBy: { createdAt: 'asc' },
  });
}

// Claude의 태그 제안을 승인 화면용으로 바꾼다.
// 기존 태그면 tagId와 DB의 이름·설명을, 새 태그면 tagId: null과 비슷한 기존 태그 목록을 담는다.
// 책 분석의 근거 문장(excerpt)이 있으면 그대로 옮긴다.
function toSuggestedTags(tags, existingTags) {
  const byName = new Map(existingTags.map((t) => [t.name, t]));
  const seen = new Set();
  const result = [];
  let nameMatched = 0;

  for (const t of tags) {
    let existing = t.existingTag;
    // 새 이름이라고 했지만 기존 태그와 이름이 완전히 같으면 그 태그로 본다 (재사용 실패로 집계)
    if (!existing && byName.has(t.name)) {
      existing = byName.get(t.name);
      nameMatched++;
    }

    const key = existing ? existing.id : `new:${t.name}`;
    if (seen.has(key)) continue;
    seen.add(key);

    result.push({
      tagId: existing?.id ?? null,
      name: existing?.name ?? t.name,
      isNew: !existing,
      category: t.category,
      description: existing ? existing.description : t.description,
      reason: t.reason,
      explanation: t.explanation,
      ...(t.excerpt !== undefined && { excerpt: t.excerpt }),
      similarExisting: existing ? [] : t.similarExisting.map(({ id, name }) => ({ id, name })),
    });
  }

  const reused = result.filter((t) => !t.isNew).length;
  console.log(
    `[태그 제안] 기존 태그 ${existingTags.length}개 중 재사용 ${reused}개, 새 태그 ${result.length - reused}개` +
      (nameMatched ? ` (이름 일치로 보정 ${nameMatched}개)` : '')
  );
  return result;
}

// 승인된 태그를 실제 Tag 행으로 바꾸고, 스크랩 연결 테이블에 넣을 값을 돌려준다.
// tagId는 본인 태그인지 확인하고, 새 이름은 만든다.
// 새 이름이 이미 내 태그에 있으면 그 태그를 쓴다 (같은 이름을 두 번 만들 수 없으므로).
async function resolveTags(tx, userId, tags) {
  const ids = tags.filter((t) => t.tagId).map((t) => t.tagId);
  const owned = await tx.tag.findMany({
    where: { userId, id: { in: ids } },
    select: { id: true },
  });
  if (owned.length !== new Set(ids).size) {
    throw httpError(400, '존재하지 않거나 내 것이 아닌 태그가 있습니다.');
  }

  const newNames = tags.filter((t) => !t.tagId).map((t) => t.name);
  const takenNames = await tx.tag.findMany({
    where: { userId, name: { in: newNames } },
    select: { name: true },
  });
  const created = new Set(newNames).size - takenNames.length;

  const resolved = [];
  for (const { tagId: givenId, name, category, description, ...link } of tags) {
    let tagId = givenId;
    if (!tagId) {
      const tag = await tx.tag.upsert({
        where: { userId_name: { userId, name } },
        update: {},
        create: { userId, name, category, description },
        select: { id: true },
      });
      tagId = tag.id;
    }
    // link: reason, explanation (+ 책은 excerpt)
    resolved.push({ ...link, tagId });
  }

  if (new Set(resolved.map((r) => r.tagId)).size !== resolved.length) {
    throw httpError(400, '같은 태그가 두 번 들어 있습니다.');
  }
  if (created > 0) console.log(`[태그 저장] 새 태그 ${created}개 생성`);
  return resolved;
}

module.exports = { findExistingTags, toSuggestedTags, resolveTags };
