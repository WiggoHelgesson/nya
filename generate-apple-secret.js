const crypto = require('crypto');

// Apple Sign In Configuration
const TEAM_ID = 'NRPNN9U77T';
const CLIENT_ID = 'com.updowncoachapp.web';
const KEY_ID = 'KNPP4V57Y4';
const PRIVATE_KEY = `-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgl4EECcE62d/8Kezq
jKvz5LMt1OQ8PkLI798NYHZFZxGgCgYIKoZIzj0DAQehRANCAASdSJBP4fWAv8Ps
ZWFUMvYM5jK0dqiJSKhHvPH3e3LcBCIhxqsuOC3G05RVaBmwvk0fitIZ19q/SEyW
nf1xA879
-----END PRIVATE KEY-----`;

// Generate JWT
function generateAppleClientSecret() {
  const now = Math.floor(Date.now() / 1000);
  const expiry = now + (180 * 24 * 60 * 60); // 180 days (max 6 months)

  // Header
  const header = {
    alg: 'ES256',
    kid: KEY_ID,
    typ: 'JWT'
  };

  // Payload
  const payload = {
    iss: TEAM_ID,
    iat: now,
    exp: expiry,
    aud: 'https://appleid.apple.com',
    sub: CLIENT_ID
  };

  // Base64URL encode
  function base64url(data) {
    return Buffer.from(JSON.stringify(data))
      .toString('base64')
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_');
  }

  const headerEncoded = base64url(header);
  const payloadEncoded = base64url(payload);
  const signatureInput = `${headerEncoded}.${payloadEncoded}`;

  // Sign with ES256
  const sign = crypto.createSign('SHA256');
  sign.update(signatureInput);
  sign.end();
  
  const signature = sign.sign(PRIVATE_KEY);
  
  // Convert DER signature to raw format (r || s)
  // ES256 signatures from Node.js are in DER format, need to convert
  function derToRaw(derSig) {
    // DER format: 0x30 [total-length] 0x02 [r-length] [r] 0x02 [s-length] [s]
    let offset = 2; // Skip 0x30 and total length
    
    // Get r
    if (derSig[offset] !== 0x02) throw new Error('Invalid DER signature');
    offset++;
    const rLength = derSig[offset];
    offset++;
    let r = derSig.slice(offset, offset + rLength);
    offset += rLength;
    
    // Get s
    if (derSig[offset] !== 0x02) throw new Error('Invalid DER signature');
    offset++;
    const sLength = derSig[offset];
    offset++;
    let s = derSig.slice(offset, offset + sLength);
    
    // Remove leading zeros and pad to 32 bytes
    while (r.length > 32 && r[0] === 0) r = r.slice(1);
    while (s.length > 32 && s[0] === 0) s = s.slice(1);
    while (r.length < 32) r = Buffer.concat([Buffer.from([0]), r]);
    while (s.length < 32) s = Buffer.concat([Buffer.from([0]), s]);
    
    return Buffer.concat([r, s]);
  }
  
  const rawSignature = derToRaw(signature);
  const signatureEncoded = rawSignature
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  const jwt = `${signatureInput}.${signatureEncoded}`;
  
  return {
    jwt,
    expiresAt: new Date(expiry * 1000).toISOString()
  };
}

try {
  const result = generateAppleClientSecret();
  console.log('\n========================================');
  console.log('APPLE CLIENT SECRET (JWT)');
  console.log('========================================\n');
  console.log(result.jwt);
  console.log('\n========================================');
  console.log('EXPIRES:', result.expiresAt);
  console.log('========================================\n');
  console.log('Copy the JWT above and paste it in Supabase Dashboard:');
  console.log('Authentication → Providers → Apple → Secret Key');
  console.log('\n⚠️  This secret expires in 180 days. Set a reminder to regenerate it!\n');
} catch (error) {
  console.error('Error generating JWT:', error.message);
}
