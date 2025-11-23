const path = require('path');

module.exports = {
  'server/**/*.{ts,tsx,js,json}': (filenames) => {
    const cwd = process.cwd();
    const relativeFiles = filenames.map(f => path.relative(path.join(cwd, 'server'), f));
    return `cd server && npx eslint --fix ${relativeFiles.join(' ')}`;
  },
  'ios-app/**/*.swift': (filenames) => {
     return `if command -v swiftlint >/dev/null; then swiftlint lint --fix ${filenames.join(' ')}; else echo "⚠️ SwiftLint not installed. Skipping iOS linting."; fi`;
  }
}

