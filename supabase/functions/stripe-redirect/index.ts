/**
 * STRIPE REDIRECT HANDLER
 * ========================
 * Handles redirects from Stripe onboarding back to the app.
 * 
 * Since Stripe requires HTTPS URLs, this function serves as an intermediary
 * that shows a success/refresh message and provides a link to open the app.
 * 
 * Usage:
 * GET /stripe-redirect?status=success
 * GET /stripe-redirect?status=refresh
 */

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const status = url.searchParams.get('status') || 'success';

  const isSuccess = status === 'success';
  
  const html = `
<!DOCTYPE html>
<html lang="sv">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${isSuccess ? 'Registrering klar!' : 'Försök igen'}</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
      color: white;
      padding: 20px;
    }
    .container {
      text-align: center;
      max-width: 400px;
    }
    .icon {
      font-size: 64px;
      margin-bottom: 24px;
    }
    h1 {
      font-size: 24px;
      margin-bottom: 16px;
    }
    p {
      color: rgba(255,255,255,0.7);
      margin-bottom: 32px;
      line-height: 1.5;
    }
    .button {
      display: inline-block;
      background: ${isSuccess ? '#22c55e' : '#3b82f6'};
      color: white;
      padding: 16px 32px;
      border-radius: 12px;
      text-decoration: none;
      font-weight: 600;
      font-size: 16px;
      transition: transform 0.2s, opacity 0.2s;
    }
    .button:hover {
      transform: scale(1.05);
      opacity: 0.9;
    }
    .footer {
      margin-top: 24px;
      font-size: 14px;
      color: rgba(255,255,255,0.5);
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">${isSuccess ? '✅' : '🔄'}</div>
    <h1>${isSuccess ? 'Stripe-registrering klar!' : 'Länken har gått ut'}</h1>
    <p>${isSuccess 
      ? 'Ditt Stripe-konto är nu kopplat. Du kan börja ta emot betalningar för dina golflektioner.'
      : 'Onboarding-länken har gått ut. Gå tillbaka till appen och försök igen.'
    }</p>
    <a href="upanddown://stripe-${status}" class="button">
      ${isSuccess ? 'Tillbaka till appen' : 'Öppna appen'}
    </a>
    <p class="footer">Up&Down Golf</p>
  </div>
  
  <script>
    // Try to automatically redirect to app after 2 seconds
    setTimeout(function() {
      window.location.href = 'upanddown://stripe-${status}';
    }, 2000);
  </script>
</body>
</html>
  `;

  return new Response(html, {
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/html; charset=utf-8',
    },
  });
});




