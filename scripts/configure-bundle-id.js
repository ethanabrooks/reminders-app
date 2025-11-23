#!/usr/bin/env node
// Configure bundle identifier in Xcode project
// Usage: node scripts/configure-bundle-id.js [bundle-id]

const { readFileSync, writeFileSync } = require('fs');
const { join } = require('path');

const bundleId = process.argv[2];

if (!bundleId) {
  console.error('Usage: node scripts/configure-bundle-id.js <bundle-id>');
  console.error('Example: node scripts/configure-bundle-id.js com.yourname.GPTReminders');
  process.exit(1);
}

const projectPath = join(__dirname, '..', 'ios-app', 'GPTReminders.xcodeproj', 'project.pbxproj');

console.log(`🔧 Configuring bundle identifier to: ${bundleId}\n`);

let content = readFileSync(projectPath, 'utf8');

// Find and replace PRODUCT_BUNDLE_IDENTIFIER
const bundleIdRegex = /PRODUCT_BUNDLE_IDENTIFIER = "[^"]+";/g;
if (bundleIdRegex.test(content)) {
  content = content.replace(bundleIdRegex, `PRODUCT_BUNDLE_IDENTIFIER = "${bundleId}";`);
  writeFileSync(projectPath, content);
  console.log('✅ Updated bundle identifier in project.pbxproj');
  console.log('\n⚠️  Note: You may still need to configure signing in Xcode for device builds');
} else {
  console.error('❌ Could not find PRODUCT_BUNDLE_IDENTIFIER in project.pbxproj');
  process.exit(1);
}

