const sharp = require('sharp');

async function removeWhiteBackground(input, output) {
  const { data, info } = await sharp(input)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  const { width, height, channels } = info;
  const total = width * height;
  const candidate = new Uint8Array(total);
  const visited = new Uint8Array(total);

  for (let i = 0; i < total; i++) {
    const p = i * channels;
    const r = data[p];
    const g = data[p + 1];
    const b = data[p + 2];
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    // الخلفية الأصلية أبيض/رمادي محايد. اللون البيج في الحبل والوبر
    // أكثر تشبعًا، لذلك لا يدخل هذا القناع.
    candidate[i] = min >= 210 && max - min <= 26 ? 1 : 0;
  }

  const queue = new Int32Array(total);
  let transparent = 0;
  const neighbours = [-1, 1, -width, width];

  for (let seed = 0; seed < total; seed++) {
    if (!candidate[seed] || visited[seed]) continue;
    let head = 0;
    let tail = 0;
    let touchesEdge = false;
    queue[tail++] = seed;
    visited[seed] = 1;

    while (head < tail) {
      const i = queue[head++];
      const x = i % width;
      const y = Math.floor(i / width);
      if (x === 0 || y === 0 || x === width - 1 || y === height - 1) {
        touchesEdge = true;
      }
      for (const delta of neighbours) {
        const next = i + delta;
        if (next < 0 || next >= total || visited[next] || !candidate[next]) {
          continue;
        }
        if ((delta === -1 && x === 0) || (delta === 1 && x === width - 1)) {
          continue;
        }
        visited[next] = 1;
        queue[tail++] = next;
      }
    }

    // الفتحات الكبيرة المغلقة، مثل وسط لفة الحبل، خلفية أيضًا. أما بياض
    // العين والتفاصيل الصغيرة فيظل محفوظًا لأنه لا يلامس الحافة وصغير.
    if (touchesEdge || tail >= 40000) {
      for (let q = 0; q < tail; q++) {
        data[queue[q] * channels + 3] = 0;
      }
      transparent += tail;
    }
  }

  await sharp(data, { raw: info }).png().toFile(output);
  console.log(`${output}: ${width}x${height}, transparent=${transparent}/${total}`);
}

const [input, output] = process.argv.slice(2);
if (!input || !output) {
  throw new Error('Usage: node remove_white_background.js input.png output.png');
}
removeWhiteBackground(input, output).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
