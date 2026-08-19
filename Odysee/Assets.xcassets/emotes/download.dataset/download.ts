import { mkdirSync, createWriteStream } from 'fs';
import { Readable } from 'stream';
import { finished } from 'stream/promises';

import * as Emotes from '../ui/constants/emotes.ts';

async function downloadTwemotes(folder: string, list: Array<{ name: string, url: string }>) {
  mkdirSync(folder, { recursive: true });

  for (const emote of list) {
    const name = emote.name.slice(1, -1);
    const url = emote.url;

    const file = createWriteStream(`${folder}/${name}.png`);

    const res = await fetch(url);
    if (res.ok) {
      await finished(Readable.fromWeb(res.body).pipe(file));
      console.log(`Downloaded ${name}`);
    } else {
      console.error(res);
    }
  }
}

async function downloadEmotes(multiplier: string, list: Array<{ name: string, url: string }>) {
  const folder = 'ODYSEE';

  mkdirSync(folder, { recursive: true });

  for (const emote of list) {
    const name = emote.name.slice(1, -1);
    const url = emote.url;

    const file = createWriteStream(`${folder}/${name}${multiplier}.png`);

    const res = await fetch(url);
    if (res.ok) {
      await finished(Readable.fromWeb(res.body).pipe(file));
      console.log(`Downloaded ${name}`);
    } else {
      console.error(res);
    }
  }
}

await downloadTwemotes('SMILIES', Emotes.TWEMOTES.SMILIES!);
await downloadTwemotes('HANDSIGNALS', Emotes.TWEMOTES.HANDSIGNALS!);
await downloadTwemotes('ACTIVITIES', Emotes.TWEMOTES.ACTIVITIES!);
await downloadTwemotes('SYMBOLS', Emotes.TWEMOTES.SYMBOLS!);
await downloadTwemotes('NATURE', Emotes.TWEMOTES.NATURE!);
await downloadTwemotes('FOOD', Emotes.TWEMOTES.FOOD!);
await downloadTwemotes('FLAGS', Emotes.TWEMOTES.FLAGS!);

await downloadEmotes('', Emotes.EMOTES_24px);
await downloadEmotes('@2x', Emotes.EMOTES_48px);
await downloadEmotes('@3x', Emotes.EMOTES_72px);
