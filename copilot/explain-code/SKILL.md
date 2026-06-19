---
name: copilot-explain-code
description: Explain TypeScript files in src/ to a frontend beginner — function breakdowns, cross-file call linking, API/data flows with infra/cloud services, and design pattern detection for React, TypeScript, and Next.js.
metadata:
  type: teaching
  version: "1.0"
---

Explain TypeScript code to a frontend beginner. Break down functions, link cross-file calls, trace API/data flows with infrastructure services, and detect design patterns in React, TypeScript, and Next.js codebases.

**Input**: File path(s) or directory to explain, or empty for interactive mode

**Steps**

1. **Identify the target**

   - If a file path is provided, use it
   - If a directory is provided, find the entry point (index.ts, app.ts, main.ts, etc.)
   - If no input, ask which file/function to explain

2. **Read and analyze the code**

   ```bash
   # Read the target file(s)
   cat <file-path>

   # Find imports and dependencies
   grep -r "import.*from" <file-path>

   # Find function calls across files
   grep -rn "<function-name>" src/
   ```

3. **Explain using this structure**

   ```markdown
   ## Overview
   <What does this file/module do in plain English?>

   ## Key Functions
   ### `functionName(params): ReturnType`
   - **Purpose**: What it does
   - **Input**: What it receives
   - **Output**: What it returns
   - **Side effects**: API calls, state changes, etc.
   - **Called by**: List of files/functions that call this

   ## Data Flow
   ```
   [Component A] → (props/API call) → [Service B] → (database query) → [Database C]
   ```

   ## Design Patterns Used
   - <Pattern name>: How it's used here
   - Example: `useEffect` for data fetching, Context for state sharing, etc.

   ## Infrastructure Connections
   - API endpoints called: `GET /api/users`
   - Database tables: `users`, `sessions`
   - External services: Stripe, AWS S3, etc.

   ## Common Pitfalls
   - <Pitfall 1>: <Explanation>
   - <Pitfall 2>: <Explanation>
   ```

4. **Adapt to the user's level**

   - If they're a beginner: explain concepts, avoid jargon
   - If they're intermediate: focus on architecture and patterns
   - If they're advanced: dive into edge cases and optimizations

5. **Offer follow-ups**

   - "Want me to trace a specific function's call chain?"
   - "Should I explain the data flow in more detail?"
   - "Would you like to see how this connects to the API layer?"

**Example Output**

```markdown
## Overview
This file handles user authentication. It exports functions for login, logout, and session validation.

## Key Functions
### `login(email: string, password: string): Promise<User>`
- **Purpose**: Authenticates a user with email/password
- **Input**: Email and password strings
- **Output**: User object on success, throws on failure
- **Side effects**: Creates session in Redis, sets cookie
- **Called by**: `src/pages/login.tsx`, `src/api/auth.ts`

## Data Flow
```
[LoginForm] → (submit) → [login()] → (POST /api/auth/login) → [AuthController] → (validate) → [Database]
```

## Design Patterns Used
- **Repository Pattern**: `UserRepository` abstracts database access
- **Middleware**: Auth middleware protects routes in `src/middleware/auth.ts`

## Infrastructure Connections
- API: `POST /api/auth/login`
- Database: PostgreSQL `users` table
- Cache: Redis session store
```

**Guardrails**
- Don't assume knowledge — explain terms like "RSC", "Server Actions", etc.
- Use diagrams (ASCII) for data flows and architecture
- Reference actual file paths, not abstract descriptions
- Highlight security considerations when relevant (auth, data validation)
