const path = require('path');

module.exports = {
  // Server: Lint & Prettier
  'server/**/*.{ts,tsx,js,json}': (filenames) => {
    const cwd = process.cwd();
    const relativeFiles = filenames.map((f) => path.relative(path.join(cwd, 'server'), f));
    // 1. ESLint (fixes and checks) - run from server dir
    const eslintCmd = `cd server && npx eslint --fix ${relativeFiles.join(' ')}`;
    // 2. Prettier (formatting) - run from root on the absolute paths
    const prettierCmd = `npx prettier --write ${filenames.join(' ')}`;
    return [eslintCmd, prettierCmd];
  },

  // iOS: SwiftLint
  'ios-app/**/*.swift': (filenames) => {
    return `if command -v swiftlint >/dev/null; then swiftlint lint --fix ${filenames.join(' ')}; else echo "⚠️ SwiftLint not installed. Skipping."; fi`;
  },

  // Root/Other: Prettier only (for files not in server/)
  '*.{json,md}': (filenames) => {
    return `npx prettier --write ${filenames.join(' ')}`;
  },
  
  // Scripts: ShellCheck & shfmt
  '*.sh': (filenames) => {
    return [
      `if command -v shfmt >/dev/null; then shfmt -w -i 2 -ci -sr ${filenames.join(' ')}; fi`,
      `npx shellcheck ${filenames.join(' ')}`
    ];
  }
};
