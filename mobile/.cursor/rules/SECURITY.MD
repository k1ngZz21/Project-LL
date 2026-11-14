01 · LOGIN
Real login, passwords hashed
A login you wrote yourself is the easiest thing to get wrong.
1.Use a proven auth service (Clerk, Supabase Auth, Auth0, NextAuth) instead of your own.
2.If you must store passwords: hash them with argon2 or bcrypt. Never plain text, never plain SHA.


02 · API KEYS
Keys on the server, never in the browser
Anything in front-end code can be read by anyone.
1.Put every secret in environment variables and call the API from your server.
2.Search your front-end for sk_, api_key and secret. Found one? Rotate it.

03 · DATABASE
Lock the database
Without rules, anyone can read every user's rows.
1.Turn on row-level security or equivalent rules, default deny.
2.Test: log in as user A and try to open user B's data. It must fail.


04 · HTTPS + FORMS
HTTPS everywhere, checks on the server
Browser checks are just suggestions, anyone can skip them.
1.Force HTTPS and redirect http to https.
2.Re-check every form field on the server: type, length, range, and who is allowed to send it.

05 · XSS + SQL
Block XSS, use safe queries
Typed text can turn into code if you trust it.
1.Never build SQL by gluing strings. Use parameterized queries or your ORM.
2.Never put user text into the page as raw HTML. Let the framework escape it.

06 · RATE LIMIT + CSRF
Rate limit logins, add CSRF protection
Bots can try thousands of passwords, and other sites can send requests as your user.
1.Limit login attempts (for example 5 per minute per account and per IP) and add a delay.
2.Turn on CSRF tokens or SameSite cookies for every request that changes data.


07 · COOKIES + RESET
Secure cookies, expiring reset links
A stolen cookie or an old reset link is a free pass.
1.Session cookies: HttpOnly, Secure, SameSite=Lax.
2.Password reset links: single use, expire in about 15 minutes.




08 · UPLOADS
Limit what files people can upload
An upload box can become a way to run code on your server.
1.Allow only the types you need, set a size limit, and rename files.
2.Store uploads outside your app folder (a storage bucket), never run them.

09 · ADMIN + PRICES
Lock admin pages, recheck prices on the server
If the page is hidden but the server says yes, it is not locked.
1.Check the user's role on the server for every admin action, not just on the page.
2.Calculate prices and totals on the server from your own product list, never from what the browser sends.

10 · DEBUG
Turn off debug mode
Debug pages show paths, keys and code to strangers.
1.Set production mode (NODE_ENV=production, DEBUG=False).
2.Show users a short error and keep the details in private logs.
11 · PACKAGES
Update risky packages, delete unused ones
Old packages carry known holes, unused ones are risk for nothing.
1.Run npm audit (or pip-audit) and update what it flags.
2.Remove every package you do not use.
12 · GIT HISTORY
Scan history for leaked keys, replace any found
Deleting a key from the code does not delete it from git history.
1.Scan with gitleaks detect or GitHub secret scanning.
2.Any key that was ever committed: revoke it and make a new one.

Act as a security reviewer for my app before launch. Go through my code and do these 12 checks one by one:
1. Real login, every password hashed (argon2 or bcrypt)
2. API keys only on the server, none in the browser or in git
3. Database access rules: users only see their own data
4. HTTPS everywhere, every form checked on the server
5. XSS blocked, only safe (parameterized) queries
6. Login rate limit and CSRF protection
7. Secure session cookies, password reset links that expire
8. File uploads limited by type and size
9. Admin pages locked by role, prices rechecked on the server
10. Debug mode off in production
11. Risky packages updated, unused ones removed
12. Git history scanned for leaked keys, any found replaced
Fix each problem you find, test every fix, then send me a short report: what was wrong, what you changed, and what I must do myself (like rotating keys).
