// Helper script to generate RS256 keypair for JWT signing
import { generateKeyPairSync } from 'crypto';
import { writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';

function generateKeypair() {
  const { publicKey, privateKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
    publicKeyEncoding: {
      type: 'spki',
      format: 'pem',
    },
    privateKeyEncoding: {
      type: 'pkcs8',
      format: 'pem',
    },
  });

  const keysDir = join(__dirname, '..', 'keys');
  if (!existsSync(keysDir)) {
    mkdirSync(keysDir, { recursive: true });
  }

  writeFileSync(join(keysDir, 'private.pem'), privateKey);
  writeFileSync(join(keysDir, 'public.pem'), publicKey);

  console.log('✅ Generated RSA keypair:');
  console.log(`   Private key: ${join(keysDir, 'private.pem')}`);
  console.log(`   Public key:  ${join(keysDir, 'public.pem')}`);
  console.log('\n📱 Next steps:');
  console.log('   See ios-app/SETUP.md for detailed iOS app setup instructions');
  console.log('\n🔐 Optional: Add to server/.env for production:');
  console.log(`   COMMAND_SIGNING_PRIVATE="${privateKey.replace(/\n/g, '\\n')}"`);
}

if (require.main === module) {
  generateKeypair();
}

export { generateKeypair };
