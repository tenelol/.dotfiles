import { execFileSync } from 'node:child_process';
import { realpathSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';

// Test the installed/patched artifact; PI_EXTENSIONS_DIR selects a build fixture.
export const extensionRoot = process.env.PI_EXTENSIONS_DIR || join(homedir(), '.pi/agent/extensions');
export const extensionPath = (relative) => join(extensionRoot, relative);

// The pi package on PATH (from nixpkgs); PI_PACKAGE_DIR selects another build.
export const piPackageRoot = () =>
  process.env.PI_PACKAGE_DIR ||
  join(dirname(dirname(realpathSync(execFileSync('which', ['pi'], { encoding: 'utf8' }).trim()))), 'lib/node_modules/pi-monorepo');
