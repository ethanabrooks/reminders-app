// Helper script to generate RS256 keypair for JWT signing
import { generateKeyPairSync } from "crypto";
import { writeFileSync } from "fs";
import { join } from "path";

function generateKeypair() {
  const { publicKey, privateKey } = generateKeyPairSync("rsa", {
    modulusLength: 2048,
    publicKeyEncoding: {
      type: "spki",
      format: "pem",
    },
    privateKeyEncoding: {
      type: "pkcs8",
      format: "pem",
    },
  });

  const keysDir = join(__dirname, "..", "keys");
  const fs = require("fs");
  if (!fs.existsSync(keysDir)) {
    fs.mkdirSync(keysDir, { recursive: true });
  }

  writeFileSync(join(keysDir, "private.pem"), privateKey);
  writeFileSync(join(keysDir, "public.pem"), publicKey);

  console.log("✅ Generated RSA keypair:");
  console.log(`   Private key: ${join(keysDir, "private.pem")}`);
  console.log(`   Public key:  ${join(keysDir, "public.pem")}`);
  console.log("\n📱 iOS Setup:");
  console.log("   1. Copy server/keys/public.pem to ios-app/GPTReminders/Resources/public.pem");
  console.log("   2. Open project in Xcode and add the file (File > Add Files to 'GPTReminders')");
  console.log("   3. Ensure it's included in 'Copy Bundle Resources' build phase");
  console.log("\n🔐 Add to .env:");
  console.log(`   COMMAND_SIGNING_PRIVATE="${privateKey.replace(/\n/g, "\\n")}"`);
}

if (require.main === module) {
  generateKeypair();
}

export { generateKeypair };
