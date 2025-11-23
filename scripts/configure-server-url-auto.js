#!/usr/bin/env node
// Auto-detect Mac IP and configure server URL for Simulator
// Usage: node scripts/configure-server-url-auto.js

const { execSync } = require('child_process');
const { readFileSync, writeFileSync } = require('fs');
const { join } = require('path');

const appDelegatePath = join(__dirname, '..', 'ios-app', 'GPTReminders', 'Sources', 'AppDelegate.swift');

console.log('🔍 Detecting Mac IP address...\n');

let macIP;
try {
  // Try to get the primary network interface IP
  const output = execSync("ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1", { encoding: 'utf8' });
  const match = output.match(/inet (\d+\.\d+\.\d+\.\d+)/);
  if (match) {
    macIP = match[1];
  }
} catch (error) {
  console.error('❌ Could not detect IP address');
  process.exit(1);
}

if (!macIP) {
  console.error('❌ Could not find network IP address');
  console.log('   Please configure manually:');
  console.log('   node scripts/configure-server-url.js "http://YOUR_IP:3000"');
  process.exit(1);
}

const url = `http://${macIP}:3000`;
console.log(`📱 Detected Mac IP: ${macIP}`);
console.log(`🔧 Configuring server URL to: ${url}\n`);

let content = readFileSync(appDelegatePath, 'utf8');

// Replace the serverURL line
const urlRegex = /private let serverURL = URL\(string: "[^"]+"\)!/;
if (urlRegex.test(content)) {
  content = content.replace(urlRegex, `private let serverURL = URL(string: "${url}")!`);
  writeFileSync(appDelegatePath, content);
  console.log('✅ Updated AppDelegate.swift');
  console.log('\n⚠️  Note: If your IP changes, run this script again');
} else {
  console.error('❌ Could not find serverURL in AppDelegate.swift');
  process.exit(1);
}

