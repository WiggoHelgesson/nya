import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const url = new URL(req.url)
  const code = url.searchParams.get('code')
  const error = url.searchParams.get('error')
  const scope = url.searchParams.get('scope')

  console.log('Strava callback received:', { code: code ? 'present' : 'missing', error, scope })

  if (error) {
    // User denied access or other error
    const redirectUrl = `upanddown://strava-error?error=${encodeURIComponent(error)}`
    return Response.redirect(redirectUrl, 302)
  }

  if (!code) {
    return new Response('Missing authorization code', { status: 400 })
  }

  // Redirect to the app with the authorization code
  const redirectUrl = `upanddown://strava-callback?code=${encodeURIComponent(code)}`
  
  // Return HTML that redirects (more reliable than 302 on mobile)
  const html = `
<!DOCTYPE html>
<html>
<head>
  <title>Ansluter till Up&Down...</title>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
    }
    .container {
      text-align: center;
      padding: 40px;
    }
    h1 { font-size: 24px; margin-bottom: 16px; }
    p { font-size: 16px; opacity: 0.9; }
    .spinner {
      width: 40px;
      height: 40px;
      border: 4px solid rgba(255,255,255,0.3);
      border-top-color: white;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin: 20px auto;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    a {
      display: inline-block;
      margin-top: 20px;
      padding: 12px 24px;
      background: white;
      color: #764ba2;
      text-decoration: none;
      border-radius: 8px;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>✅ Strava ansluten!</h1>
    <div class="spinner"></div>
    <p>Återgår till Up&Down...</p>
    <a href="${redirectUrl}">Öppna Up&Down</a>
  </div>
  <script>
    // Try to redirect automatically
    window.location.href = "${redirectUrl}";
    
    // Fallback: try again after a short delay
    setTimeout(function() {
      window.location.href = "${redirectUrl}";
    }, 1000);
  </script>
</body>
</html>
  `

  return new Response(html, {
    headers: { 'Content-Type': 'text/html; charset=utf-8' }
  })
})













