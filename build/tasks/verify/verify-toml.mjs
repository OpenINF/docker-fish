import { execute } from '@yarnpkg/shell';
import { $ } from 'zx';

import { echoTaskRunning } from '../util.mjs';

echoTaskRunning('verify-toml', import.meta.url);

const TOMLObject =
  await $`bundle exec github-linguist --breakdown --json | jq '.TOML.files'`;
const TOMLFiles = JSON.parse(TOMLObject.stdout);

let exitCode = 0;
const scripts = [
  `dprint check ${TOMLFiles.join(' ')}`, // validate & style-check
];

for await (const element of scripts) {
  try {
    exitCode = await execute(`pnpm exec ${element}`);
  } catch (p) {
    exitCode = p.exitCode;
  }
  process.exitCode = exitCode > 0 ? exitCode : 0;
}
