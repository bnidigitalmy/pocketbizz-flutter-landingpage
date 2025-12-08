-- Create function to automatically create user profile when auth user is created
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email)
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to call function when new auth user is created
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Also ensure RLS policies are set up correctly
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
-- This is now handled by trigger, but keeping for manual inserts
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


