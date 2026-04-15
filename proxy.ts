import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'
import { createServerClient as _createServerClient } from '@supabase/ssr'

export async function proxy(request: NextRequest) {
  // Handle /admin 404 by redirecting to dashboard
  if (request.nextUrl.pathname === '/admin') {
    return NextResponse.redirect(new URL('/dashboard', request.url))
  }

  let response = NextResponse.next({
    request: {
      headers: request.headers,
    },
  })

  const supabase = _createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          )
          response = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  // Refresh session cookies and verify auth
  await supabase.auth.getUser()

  return response
}

export const config = {
  matcher: [
    '/((?!api|_next/static|_next/image|favicon.ico|.*\\.png$|.*\\.svg$).*)',
  ],
}
