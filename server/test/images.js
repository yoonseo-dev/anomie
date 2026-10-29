// 테스트용 가짜 이미지. 형식·크기 검사에 쓰는 헤더만 진짜처럼 만든다 (OCR은 테스트에서 가짜로 바꾼다).

function fakePng(width, height) {
  const buf = Buffer.alloc(64);
  buf.writeUInt32BE(0x89504e47, 0);
  buf.writeUInt32BE(0x0d0a1a0a, 4);
  buf.writeUInt32BE(13, 8); // IHDR 길이
  buf.write('IHDR', 12, 'ascii');
  buf.writeUInt32BE(width, 16);
  buf.writeUInt32BE(height, 20);
  return buf;
}

function fakeJpeg(width, height) {
  const app0 = Buffer.from([0xff, 0xe0, 0x00, 0x10, ...Buffer.from('JFIF\0'), 1, 1, 0, 0, 1, 0, 1, 0, 0]);
  const sof0 = Buffer.alloc(19);
  sof0.writeUInt16BE(0xffc0, 0);
  sof0.writeUInt16BE(17, 2);
  sof0[4] = 8;
  sof0.writeUInt16BE(height, 5);
  sof0.writeUInt16BE(width, 7);
  return Buffer.concat([Buffer.from([0xff, 0xd8]), app0, sof0, Buffer.alloc(16)]);
}

// variant: 'VP8 '(손실), 'VP8L'(무손실), 'VP8X'(확장)
function fakeWebp(width, height, variant = 'VP8 ') {
  const buf = Buffer.alloc(40);
  buf.write('RIFF', 0, 'ascii');
  buf.writeUInt32LE(32, 4);
  buf.write('WEBP', 8, 'ascii');
  buf.write(variant, 12, 'ascii');
  if (variant === 'VP8 ') {
    buf.writeUIntBE(0x9d012a, 23, 3);
    buf.writeUInt16LE(width, 26);
    buf.writeUInt16LE(height, 28);
  } else if (variant === 'VP8L') {
    buf[20] = 0x2f;
    buf.writeUInt32LE(((width - 1) | ((height - 1) << 14)) >>> 0, 21);
  } else {
    buf.writeUIntLE(width - 1, 24, 3);
    buf.writeUIntLE(height - 1, 27, 3);
  }
  return buf;
}

module.exports = { fakePng, fakeJpeg, fakeWebp };
