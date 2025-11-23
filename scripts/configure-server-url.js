#!/usr/bin/env node
// Configure server URL in AppDelegate.swift
// Usage: node scripts/configure-server-url.js [URL]

const { readFileSync, writeFileSync } = require('fs');
const { join } = require('path');

const appDelegatePath = join(__dirname, '..', 'ios-app', 'GPTReminders', 'Sources', 'AppDelegate.swift');

const url = process.argv[2] || 'http://localhost:3000';

console.log(`🔧 Configuring server URL to: ${url}\n`);

let content = readFileSync(appDelegatePath, 'utf8');

// Replace the serverURL line
const urlRegex = /private let serverURL = URL\(string: "[^"]+"\)!/;
if (urlRegex.test(content)) {
  content = content.replace(urlRegex, `private let serverURL = URL(string: "${url}")!`);
  writeFileSync(appDelegatePath, content);
  console.log('✅ Updated AppDelegate.swift');
} else {
  console.error('❌ Could not find serverURL in AppDelegate.swift');
  process.exit(1);
}

