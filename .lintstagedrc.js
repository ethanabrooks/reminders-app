const path = require('path');

module.exports = {
  'server/**/*.{ts,tsx,js,json}': (filenames) => {
    const cwd = process.cwd();
    const relativeFiles = filenames.map((f) => path.relative(path.join(cwd, 'server'), f));
    return `cd server && npx eslint --fix ${relativeFiles.join(' ')}`;
  },
  'ios-app/**/*.swift': (filenames) => {
    return `swiftlint lint --fix ${filenames.join(' ')}`;
  },
};
