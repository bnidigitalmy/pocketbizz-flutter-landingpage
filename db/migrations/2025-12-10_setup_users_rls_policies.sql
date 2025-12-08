-- Enable Row Level Security on users table
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Users can view their own profile" ON users;
DROP POLICY IF EXISTS "Users can insert their own profile" ON users;
DROP POLICY IF EXISTS "Users can update their own profile" ON users;

-- Policy: Users can view their own profile
CREATE POLICY "Users can view their own profile"
ON users
FOR SELECT
USING (id = auth.uid());

-- Policy: Users can insert their own profile (during registration)
CREATE POLICY "Users can insert their own profile"
ON users
FOR INSERT
WITH CHECK (id = auth.uid());

-- Policy: Users can update their own profile
CREATE POLICY "Users can update their own profile"
ON users
FOR UPDATE
USING (id = auth.uid())
WITH CHECK (id = auth.uid());


