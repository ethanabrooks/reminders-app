#!/usr/bin/env node
// Script to add public.pem to Xcode project bundle
// Usage: node scripts/add-public-key-to-xcode.js

const { execSync } = require('child_process');
const { existsSync, copyFileSync, mkdirSync, readFileSync, writeFileSync } = require('fs');
const { join } = require('path');

const projectRoot = join(__dirname, '..');
const serverKeysDir = join(projectRoot, 'server', 'keys');
const publicKeySource = join(serverKeysDir, 'public.pem');
const iosAppDir = join(projectRoot, 'ios-app', 'GPTReminders');
const publicKeyDest = join(iosAppDir, 'public.pem');
const xcodeProject = join(projectRoot, 'ios-app', 'GPTReminders.xcodeproj', 'project.pbxproj');

console.log('🔑 Adding public.pem to Xcode project...\n');

// 1. Check if source file exists
if (!existsSync(publicKeySource)) {
  console.error('❌ Error: public.pem not found at:', publicKeySource);
  console.error('   Run: cd server && npm run gen-keys');
  process.exit(1);
}

// 2. Copy file to GPTReminders directory (where it should be based on project.pbxproj)
console.log('📋 Copying public.pem to GPTReminders directory...');
copyFileSync(publicKeySource, publicKeyDest);
console.log('   ✅ Copied to:', publicKeyDest);

// 3. Check if already in project.pbxproj
const projectContent = readFileSync(xcodeProject, 'utf8');
if (projectContent.includes('public.pem')) {
  console.log('\n✅ File is already referenced in project.pbxproj');
  console.log('   The file should now be visible in Xcode!');
  console.log('\n   If it doesn\'t appear, try:');
  console.log('   1. Close and reopen Xcode');
  console.log('   2. Or right-click GPTReminders folder → Add Files → Select public.pem');
} else {
  console.log('\n⚠️  File copied but not yet in project.pbxproj');
  console.log('   You need to add it manually in Xcode:');
  console.log('   1. Open Xcode');
  console.log('   2. Right-click gray "GPTReminders" folder');
  console.log('   3. Select "Add Files to GPTReminders"');
  console.log('   4. Select public.pem (should be in GPTReminders/ folder)');
  console.log('   5. Ensure "Copy items if needed" is UNCHECKED');
  console.log('   6. Ensure "Add to targets: GPTReminders" is CHECKED');
}

console.log('\n✅ Setup complete!');
