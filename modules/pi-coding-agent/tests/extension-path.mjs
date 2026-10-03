import { homedir } from 'node:os';
import { join } from 'node:path';

// Test the installed/patched artifact; PI_EXTENSIONS_DIR selects a build fixture.
export const extensionRoot = process.env.PI_EXTENSIONS_DIR || join(homedir(), '.pi/agent/extensions');
export const extensionPath = (relative) => join(extensionRoot, relative);
