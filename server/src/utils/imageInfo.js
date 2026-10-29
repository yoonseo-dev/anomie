// WebP: RIFF 컨테이너 안의 첫 청크(VP8 / VP8L / VP8X)에서 크기를 읽는다
function webpSize(buf) {
  const chunk = buf.toString('ascii', 12, 16);
  if (chunk === 'VP8 ' && buf.length >= 30 && buf.readUIntBE(23, 3) === 0x9d012a) {
    return { width: buf.readUInt16LE(26) & 0x3fff, height: buf.readUInt16LE(28) & 0x3fff };
  }
  if (chunk === 'VP8L' && buf.length >= 25 && buf[20] === 0x2f) {
    const bits = buf.readUInt32LE(21);
    return { width: (bits & 0x3fff) + 1, height: ((bits >> 14) & 0x3fff) + 1 };
  }
  if (chunk === 'VP8X' && buf.length >= 30) {
    return { width: buf.readUIntLE(24, 3) + 1, height: buf.readUIntLE(27, 3) + 1 };
  }
  return null;
}

// 이미지 파일 앞부분만 읽어 형식과 크기를 알아낸다. JPEG·PNG·WebP만 지원하고, 그 밖이면 null.
// 확장자나 Content-Type은 믿지 않고 실제 바이트를 본다 (확장자가 .jpg인 WebP도 흔하다).
function imageInfo(buf) {
  if (!Buffer.isBuffer(buf) || buf.length < 24) return null;

  if (buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') {
    const size = webpSize(buf);
    return size && { type: 'webp', ...size };
  }

  // PNG: 시그니처 8바이트 뒤 IHDR 청크에 너비·높이
  if (buf.readUInt32BE(0) === 0x89504e47 && buf.readUInt32BE(4) === 0x0d0a1a0a) {
    return { type: 'png', width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
  }

  // JPEG: SOI(FFD8) 뒤 마커를 따라가다 SOF(프레임 시작) 마커에서 크기를 읽는다
  if (buf[0] === 0xff && buf[1] === 0xd8) {
    let i = 2;
    while (i + 9 < buf.length) {
      if (buf[i] !== 0xff) return null;
      const marker = buf[i + 1];
      // SOF0~SOF15 중 DHT(C4)·JPG(C8)·DAC(CC)는 프레임 마커가 아니다
      if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
        return { type: 'jpeg', height: buf.readUInt16BE(i + 5), width: buf.readUInt16BE(i + 7) };
      }
      i += 2 + buf.readUInt16BE(i + 2);
    }
  }
  return null;
}

module.exports = imageInfo;
