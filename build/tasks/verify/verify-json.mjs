import { echoTaskRunning } from '../util.mjs';

echoTaskRunning('verify-json', import.meta.url);

// TODO(DerekNonGeneric): Implement this task.
process.exitCode = 0;

// eslint-disable-next-line unicorn/no-process-exit
process.exit(0);